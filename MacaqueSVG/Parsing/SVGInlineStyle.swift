import Foundation

/// Parses the SVG `style` attribute (CSS declarations). Applied after presentation attributes;
/// each recognized property overwrites the corresponding `SVGStyle` field.
enum SVGInlineStyle {
    static func apply(_ styleAttribute: String?, to style: inout SVGStyle) {
        guard let styleAttribute else { return }
        let declarations = styleAttribute.split(separator: ";")
        for declaration in declarations {
            let parts = declaration.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parts.count == 2 else { continue }
            let key = parts[0].lowercased()
            var value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if let importantRange = value.range(of: "!important", options: .caseInsensitive) {
                value = String(value[..<importantRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if value.isEmpty { continue }

            switch key {
            case "fill":
                style.fill = value
            case "stroke":
                style.stroke = value
            case "stroke-width":
                style.strokeWidth = SVGScalarParsing.parseCSSValueLength(value)
            case "opacity":
                style.opacity = SVGScalarParsing.parseCGFloat(value)
            case "stop-color":
                style.fill = value
            case "stop-opacity":
                style.opacity = SVGScalarParsing.parseCGFloat(value)
            default:
                break
            }
        }
    }
}

extension SVGScalarParsing {
    /// Parses a CSS length used in `style` (e.g. `2`, `2px`); returns `nil` for `%` etc.
    static func parseCSSValueLength(_ raw: String) -> CGFloat? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("%") {
            return nil
        }
        return parseCGFloat(trimmed)
    }
}
