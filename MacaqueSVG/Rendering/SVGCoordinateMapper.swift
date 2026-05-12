import CoreGraphics
import Foundation

/// Bidirectional coordinate mapping between view (screen) space and SVG document (user) space
/// using xMidYMid meet semantics consistent with `SVGViewBoxMapping`.
enum SVGCoordinateMapper {

    /// Convert a screen/view point to SVG user-space coordinates.
    static func viewToDocument(point: CGPoint, viewSize: CGSize, viewBox: CGRect) -> CGPoint {
        let transform = SVGViewBoxMapping.userSpaceToView(viewSize: viewSize, viewBox: viewBox)
        guard isInvertible(transform) else { return point }
        return point.applying(transform.inverted())
    }

    /// Convert an SVG user-space point to screen/view coordinates.
    static func documentToView(point: CGPoint, viewSize: CGSize, viewBox: CGRect) -> CGPoint {
        let transform = SVGViewBoxMapping.userSpaceToView(viewSize: viewSize, viewBox: viewBox)
        return point.applying(transform)
    }

    /// Convert a rect from SVG user-space to view coordinates.
    static func documentToView(rect: CGRect, viewSize: CGSize, viewBox: CGRect) -> CGRect {
        let transform = SVGViewBoxMapping.userSpaceToView(viewSize: viewSize, viewBox: viewBox)
        return rect.applying(transform)
    }

    /// The uniform scale factor applied under xMidYMid meet.
    static func currentScale(viewSize: CGSize, viewBox: CGRect) -> CGFloat {
        guard viewBox.width > 0, viewBox.height > 0 else { return 1 }
        let width = max(viewSize.width, 1)
        let height = max(viewSize.height, 1)
        return min(width / viewBox.width, height / viewBox.height)
    }

    private static func isInvertible(_ t: CGAffineTransform) -> Bool {
        let det = t.a * t.d - t.b * t.c
        return abs(det) > 1e-12
    }
}
