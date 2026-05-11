import CoreGraphics
import Foundation

/// `<use href="#id" x="" y=""/>` — renders the referenced element at an offset.
final class SVGUse: SVGElement {
    /// Fragment id without `#` (e.g. `logo` for `href="#logo"`).
    var hrefFragment: String
    var x: CGFloat
    var y: CGFloat
    var useWidth: CGFloat?
    var useHeight: CGFloat?

    init(
        hrefFragment: String,
        x: CGFloat = 0,
        y: CGFloat = 0,
        useWidth: CGFloat? = nil,
        useHeight: CGFloat? = nil,
        svgId: String? = nil,
        transform: CGAffineTransform = .identity,
        style: SVGStyle = SVGStyle()
    ) {
        self.hrefFragment = hrefFragment
        self.x = x
        self.y = y
        self.useWidth = useWidth
        self.useHeight = useHeight
        super.init(svgId: svgId, transform: transform, style: style)
    }
}

enum SVGUseAttributeParsing {
    static func hrefFragment(from attributes: [String: String]) -> String? {
        let raw = attributes["href"]
            ?? attributes["xlink:href"]
            ?? attributes["{http://www.w3.org/1999/xlink}href"]
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if raw.hasPrefix("#") {
            return String(raw.dropFirst())
        }
        if let hash = raw.firstIndex(of: "#") {
            return String(raw[raw.index(after: hash)...])
        }
        return nil
    }
}
