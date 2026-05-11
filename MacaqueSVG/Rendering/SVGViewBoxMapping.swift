import CoreGraphics
import Foundation

extension SVGRoot {
    /// User-space rectangle used to fit the preview when `viewBox` or width/height are available.
    func userSpaceViewport(defaultSize: CGSize = CGSize(width: 320, height: 320)) -> CGRect {
        if let viewBox {
            return viewBox
        }
        let width = width ?? defaultSize.width
        let height = height ?? defaultSize.height
        return CGRect(x: 0, y: 0, width: width, height: height)
    }
}

enum SVGViewBoxMapping {
    /// Maps SVG user coordinates into view pixels (xMidYMid meet).
    static func userSpaceToView(viewSize: CGSize, viewBox: CGRect) -> CGAffineTransform {
        guard viewBox.width > 0, viewBox.height > 0 else {
            return .identity
        }

        let width = max(viewSize.width, 1)
        let height = max(viewSize.height, 1)
        let scale = min(width / viewBox.width, height / viewBox.height)
        let translateX = (width - viewBox.width * scale) / 2 - viewBox.minX * scale
        let translateY = (height - viewBox.height * scale) / 2 - viewBox.minY * scale

        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: translateX, ty: translateY)
    }
}
