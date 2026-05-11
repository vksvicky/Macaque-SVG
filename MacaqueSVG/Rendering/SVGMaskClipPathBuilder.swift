import CoreGraphics
import SwiftUI

/// Builds a single clip path from simple `<mask>` children (`polygon`, `rect`, `circle`, `path`).
/// Assumes `maskContentUnits="userSpaceOnUse"` (default): geometry is in the same user space as the scene.
enum SVGMaskClipPathBuilder {
    static func combinedPath(from mask: SVGMask) -> Path? {
        var combined = Path()
        var hasGeometry = false
        for child in mask.children {
            if let polygon = child as? SVGPolygon {
                combined.addPath(pathFromPolyline(polygon, close: true))
                hasGeometry = true
            } else if let polyline = child as? SVGPolyline {
                combined.addPath(pathFromPolyline(polyline, close: polyline is SVGPolygon))
                hasGeometry = true
            } else if let rect = child as? SVGRect {
                combined.addPath(roundedRectPath(rect))
                hasGeometry = true
            } else if let circle = child as? SVGCircle {
                let rect = CGRect(
                    x: circle.cx - circle.r,
                    y: circle.cy - circle.r,
                    width: circle.r * 2,
                    height: circle.r * 2
                )
                combined.addPath(Path(ellipseIn: rect))
                hasGeometry = true
            } else if let svgPath = child as? SVGPath {
                combined.addPath(SVGPathDataParser.path(from: svgPath.d))
                hasGeometry = true
            }
        }
        guard hasGeometry else { return nil }
        let bounds = combined.boundingRect
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        return combined
    }

    private static func pathFromPolyline(_ poly: SVGPolyline, close: Bool) -> Path {
        var path = Path()
        guard let first = poly.points.first else { return path }
        path.move(to: first)
        for point in poly.points.dropFirst() {
            path.addLine(to: point)
        }
        if close {
            path.closeSubpath()
        }
        return path
    }

    private static func roundedRectPath(_ rect: SVGRect) -> Path {
        let frame = CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
        let radiusX = rect.rx ?? 0
        let radiusY = rect.ry ?? rect.rx ?? 0
        guard radiusX > 0, radiusY > 0 else {
            return Path(frame)
        }
        var path = Path()
        path.addRoundedRect(in: frame, cornerSize: CGSize(width: radiusX, height: radiusY))
        return path
    }
}
