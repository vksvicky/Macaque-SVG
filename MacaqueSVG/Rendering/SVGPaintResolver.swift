import AppKit
import SwiftUI

enum SVGPaintResolver {
    /// Solid color for `<stop stop-color="…"/>` (no `url()`).
    static func colorForGradientStop(_ raw: String?) -> Color {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return .black
        }
        if raw.lowercased() == "currentcolor" {
            return Color(nsColor: .labelColor)
        }
        return color(from: raw) ?? .black
    }

    /// SVG initial fill is black when unspecified; `none` suppresses fill.
    static func fillColor(_ raw: String?) -> Color? {
        guard let raw else { return .black }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .black }
        if trimmed.lowercased() == "none" { return nil }
        if trimmed.lowercased().hasPrefix("url(") { return nil }
        if trimmed.lowercased() == "currentcolor" { return Color(nsColor: .labelColor) }
        return color(from: trimmed) ?? .black
    }

    /// Solid fill for AppKit drawing (e.g. text-on-path cache).
    static func nsColor(forFill raw: String?) -> NSColor? {
        guard let color = fillColor(raw) else { return nil }
        return NSColor(color)
    }

    static func strokeColor(_ raw: String?) -> Color? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.lowercased() == "none" { return nil }
        if trimmed.lowercased().hasPrefix("url(") { return nil }
        if trimmed.lowercased() == "currentcolor" { return Color(nsColor: .labelColor) }
        return color(from: trimmed)
    }

    private static func color(from raw: String) -> Color? {
        let lower = raw.lowercased()
        if lower.hasPrefix("#") {
            return colorFromHex(String(lower.dropFirst()))
        }
        if lower.hasPrefix("rgb") {
            return colorFromRGBFunction(raw)
        }
        return namedColor(lower)
    }

    private static func colorFromHex(_ digits: String) -> Color? {
        let clean = digits.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }

        var hex = clean
        if hex.count == 3 {
            hex = hex.map { character in "\(character)\(character)" }.joined()
        }
        guard hex.count == 6 || hex.count == 8, let value = UInt32(hex, radix: 16) else { return nil }

        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        if hex.count == 6 {
            red = CGFloat((value & 0xFF0000) >> 16) / 255
            green = CGFloat((value & 0x00FF00) >> 8) / 255
            blue = CGFloat(value & 0x0000FF) / 255
            alpha = 1
        } else {
            red = CGFloat((value & 0xFF00_0000) >> 24) / 255
            green = CGFloat((value & 0x00FF_0000) >> 16) / 255
            blue = CGFloat((value & 0x0000_FF00) >> 8) / 255
            alpha = CGFloat(value & 0x0000_00FF) / 255
        }

        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    private static func colorFromRGBFunction(_ raw: String) -> Color? {
        let trimmedParenthesis = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        guard let open = trimmedParenthesis.firstIndex(of: "("),
              let close = trimmedParenthesis.lastIndex(of: ")")
        else { return nil }

        let body = trimmedParenthesis[trimmedParenthesis.index(after: open)..<close]
        let parts = body.split(whereSeparator: { $0 == "," }).map(String.init)
        guard parts.count >= 3 else { return nil }

        func parseComponent(_ string: String) -> CGFloat? {
            if string.hasSuffix("%") {
                let numeric = string.dropLast()
                guard let value = Double(numeric) else { return nil }
                return CGFloat(value / 100)
            }
            guard let value = Double(string) else { return nil }
            return CGFloat(min(max(value / 255, 0), 1))
        }

        guard let red = parseComponent(parts[0]),
              let green = parseComponent(parts[1]),
              let blue = parseComponent(parts[2])
        else { return nil }

        let alpha: CGFloat
        if parts.count >= 4, let parsedAlpha = Double(parts[3]) {
            alpha = CGFloat(parsedAlpha)
        } else {
            alpha = 1
        }

        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    private static func namedColor(_ name: String) -> Color? {
        let mapping: [String: NSColor] = [
            "black": .black,
            "white": .white,
            "red": .systemRed,
            "green": .systemGreen,
            "blue": .systemBlue,
            "gray": .gray,
            "grey": .gray,
            "yellow": .systemYellow,
            "orange": .systemOrange,
            "purple": .systemPurple,
            "cyan": .systemCyan,
            "magenta": .systemPink,
            "pink": .systemPink,
            "brown": .brown,
        ]
        guard let nsColor = mapping[name] else { return nil }
        return Color(nsColor: nsColor)
    }
}
