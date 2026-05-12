import CoreGraphics
import SwiftUI

/// Draws selection handles (bounding box + resize grips) for the active element
/// directly into a GraphicsContext that already has viewBox mapping applied.
enum SVGSelectionOverlay {
    private static let handleSize: CGFloat = 6
    private static let strokeColor = Color.blue
    private static let dashPattern: [CGFloat] = [6, 3]

    /// Draw the selection box and handles in document (SVG user-space) coordinates.
    /// Call this after the SVG content has been drawn, while the viewBox transform is still active.
    static func drawSelection(element: SVGElement?, context: inout GraphicsContext) {
        guard let element, let bounds = elementBounds(element) else { return }

        let path = SwiftUI.Path(bounds)
        context.stroke(
            path,
            with: .color(strokeColor),
            style: StrokeStyle(lineWidth: 1.5, dash: dashPattern)
        )

        for handle in handlePoints(of: bounds) {
            let handleRect = CGRect(
                x: handle.x - handleSize / 2,
                y: handle.y - handleSize / 2,
                width: handleSize,
                height: handleSize
            )
            context.fill(Path(handleRect), with: .color(.white))
            context.stroke(Path(handleRect), with: .color(strokeColor), lineWidth: 1.5)
        }
    }

    // MARK: - Bounds Computation

    static func elementBounds(_ element: SVGElement) -> CGRect? {
        let local: CGRect
        switch element {
        case let rect as SVGRect:
            local = CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
        case let circle as SVGCircle:
            local = CGRect(
                x: circle.cx - circle.r,
                y: circle.cy - circle.r,
                width: circle.r * 2,
                height: circle.r * 2
            )
        case let path as SVGPath:
            let swiftUIPath = SVGPathDataParser.path(from: path.d)
            let bounds = swiftUIPath.boundingRect
            guard !bounds.isEmpty else { return nil }
            local = bounds
        case let polygon as SVGPolygon:
            guard let bounds = polylineBounds(polygon.points) else { return nil }
            local = bounds
        case let polyline as SVGPolyline:
            guard let bounds = polylineBounds(polyline.points) else { return nil }
            local = bounds
        default:
            return nil
        }
        return local.applying(accumulatedTransform(for: element))
    }

    private static func polylineBounds(_ points: [CGPoint]) -> CGRect? {
        guard let first = points.first else { return nil }
        var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }
        let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        guard rect.width > 0 || rect.height > 0 else { return nil }
        return rect
    }

    private static func accumulatedTransform(for element: SVGElement) -> CGAffineTransform {
        var transform = element.transform
        var current: SVGGroup? = element.parent
        while let ancestor = current {
            transform = transform.concatenating(ancestor.transform)
            current = ancestor.parent
        }
        return transform
    }

    // MARK: - Handle Points

    private static func handlePoints(of rect: CGRect) -> [CGPoint] {
        [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.midY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.midX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.midY),
        ]
    }
}
