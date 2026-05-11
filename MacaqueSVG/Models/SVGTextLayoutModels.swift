import AppKit
import CoreGraphics
import Foundation

/// `<text>` with optional `<textPath>` / `<tspan>` children, or plain character content.
final class SVGTextBlock: SVGGroup {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var plainText: String = ""
    var fontFamily: String?
    var fontSize: CGFloat?
    /// Numeric weight when `font-weight` is a number (e.g. 600, 700).
    var fontWeightValue: CGFloat?
    var letterSpacing: String?
}

/// Text laid out along a referenced `<path id="…">`.
final class SVGTextPath: SVGGroup {
    /// `#id` fragment referencing a path definition.
    var pathHrefFragment: String = ""
    var startOffset: String?
    var textAnchor: String?
    weak var hostTextBlock: SVGTextBlock?
    /// Character data placed directly inside `<textPath>` (no `<tspan>`), e.g. `POLYCODE`.
    var inlineText: String = ""
    /// Cached bitmap + destination rect in SVG user space (built on first draw).
    var cachedRender: (image: NSImage, destination: CGRect)?
}

/// `<tspan>` fragment inside `<textPath>`.
final class SVGTSpanNode: SVGElement {
    var text: String = ""

    init(
        svgId: String? = nil,
        transform: CGAffineTransform = .identity,
        style: SVGStyle = SVGStyle()
    ) {
        super.init(svgId: svgId, transform: transform, style: style)
    }
}
