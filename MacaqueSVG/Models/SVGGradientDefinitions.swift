import CoreGraphics
import SwiftUI

struct SVGGradientStop {
    var offset: CGFloat
    var color: Color
}

/// `<linearGradient>` in `<defs>` — referenced by `fill="url(#id)"`.
final class SVGLinearGradientDef: SVGElement {
    var x1: CGFloat
    var y1: CGFloat
    var x2: CGFloat
    var y2: CGFloat
    /// `objectBoundingBox` (default per SVG) or `userSpaceOnUse`.
    var gradientUnits: String
    private(set) var stops: [SVGGradientStop] = []

    init(
        x1: CGFloat = 0,
        y1: CGFloat = 0,
        x2: CGFloat = 1,
        y2: CGFloat = 0,
        gradientUnits: String = "objectBoundingBox",
        svgId: String? = nil,
        transform: CGAffineTransform = .identity,
        style: SVGStyle = SVGStyle()
    ) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
        self.gradientUnits = gradientUnits
        super.init(svgId: svgId, transform: transform, style: style)
    }

    func appendStop(_ stop: SVGGradientStop) {
        stops.append(stop)
    }
}

/// `<radialGradient>` in `<defs>` — referenced by `fill="url(#id)"`.
final class SVGRadialGradientDef: SVGElement {
    var cx: CGFloat
    var cy: CGFloat
    var r: CGFloat
    var gradientUnits: String
    private(set) var stops: [SVGGradientStop] = []

    init(
        cx: CGFloat = 0.5,
        cy: CGFloat = 0.5,
        r: CGFloat = 0.5,
        gradientUnits: String = "objectBoundingBox",
        svgId: String? = nil,
        transform: CGAffineTransform = .identity,
        style: SVGStyle = SVGStyle()
    ) {
        self.cx = cx
        self.cy = cy
        self.r = r
        self.gradientUnits = gradientUnits
        super.init(svgId: svgId, transform: transform, style: style)
    }

    func appendStop(_ stop: SVGGradientStop) {
        stops.append(stop)
    }
}
