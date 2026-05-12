import CoreGraphics
import Foundation
import SwiftUI

/// Hit-testing engine that determines which SVGElement lies under a given point in SVG user space.
enum SVGHitTester {

    /// Returns the deepest (topmost visually) element at `point` in SVG user-space coordinates.
    /// Traverses children in reverse order so that last-drawn (topmost) elements are hit first.
    static func hitTest(point: CGPoint, root: SVGRoot, idIndex: [String: SVGElement]) -> SVGElement? {
        return hitTestGroup(point: point, group: root, parentTransform: root.transform)
    }

    // MARK: - Private

    private static func hitTestGroup(point: CGPoint, group: SVGGroup, parentTransform: CGAffineTransform) -> SVGElement? {
        if group is SVGDefinitionContainer || group is SVGMask {
            return nil
        }

        for child in group.children.reversed() {
            guard child.isVisible else { continue }
            let combinedTransform = child.transform.concatenating(parentTransform)

            if let childGroup = child as? SVGGroup {
                if childGroup is SVGDefinitionContainer || childGroup is SVGMask {
                    continue
                }
                if let hit = hitTestGroup(point: point, group: childGroup, parentTransform: combinedTransform) {
                    return hit
                }
            } else if hitTestElement(point: point, element: child, combinedTransform: combinedTransform) {
                return child
            }
        }

        return nil
    }

    private static func hitTestElement(point: CGPoint, element: SVGElement, combinedTransform: CGAffineTransform) -> Bool {
        let localPoint = transformedPoint(point, inversOf: combinedTransform)
        guard let localPoint else { return false }

        switch element {
        case let rect as SVGRect:
            return hitTestRect(point: localPoint, rect: rect)
        case let circle as SVGCircle:
            return hitTestCircle(point: localPoint, circle: circle)
        case let path as SVGPath:
            return hitTestPath(point: localPoint, path: path)
        case let polygon as SVGPolygon:
            return hitTestPolygon(point: localPoint, polygon: polygon)
        case let polyline as SVGPolyline:
            return hitTestPolyline(point: localPoint, polyline: polyline)
        default:
            return false
        }
    }

    private static func transformedPoint(_ point: CGPoint, inversOf transform: CGAffineTransform) -> CGPoint? {
        let det = transform.a * transform.d - transform.b * transform.c
        guard abs(det) > 1e-12 else { return nil }
        let inverse = transform.inverted()
        return point.applying(inverse)
    }

    private static func hitTestRect(point: CGPoint, rect: SVGRect) -> Bool {
        let bounds = CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
        return bounds.contains(point)
    }

    private static func hitTestCircle(point: CGPoint, circle: SVGCircle) -> Bool {
        let dx = point.x - circle.cx
        let dy = point.y - circle.cy
        return (dx * dx + dy * dy) <= (circle.r * circle.r)
    }

    private static func hitTestPath(point: CGPoint, path: SVGPath) -> Bool {
        let swiftUIPath = SVGPathDataParser.path(from: path.d)
        return swiftUIPath.contains(point, eoFill: false)
    }

    private static func hitTestPolygon(point: CGPoint, polygon: SVGPolygon) -> Bool {
        guard polygon.points.count >= 3 else { return false }
        var path = Path()
        path.move(to: polygon.points[0])
        for i in 1..<polygon.points.count {
            path.addLine(to: polygon.points[i])
        }
        path.closeSubpath()
        return path.contains(point, eoFill: false)
    }

    private static func hitTestPolyline(point: CGPoint, polyline: SVGPolyline) -> Bool {
        guard polyline.points.count >= 2 else { return false }
        let tolerance: CGFloat = 4.0
        for i in 0..<(polyline.points.count - 1) {
            let a = polyline.points[i]
            let b = polyline.points[i + 1]
            if distanceToSegment(point: point, a: a, b: b) <= tolerance {
                return true
            }
        }
        return false
    }

    private static func distanceToSegment(point: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSq = dx * dx + dy * dy
        guard lengthSq > 0 else {
            return hypot(point.x - a.x, point.y - a.y)
        }
        let t = max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSq))
        let projX = a.x + t * dx
        let projY = a.y + t * dy
        return hypot(point.x - projX, point.y - projY)
    }
}
