import Foundation

enum SVGURLPaintParser {
    /// Returns the fragment id for `url(#id)` / `url('#id')` (trimmed, no `#`).
    static func paintServerFragment(from raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let lower = raw.lowercased()
        guard lower.hasPrefix("url(") else { return nil }
        guard let open = raw.firstIndex(of: "("),
              let close = raw.lastIndex(of: ")"),
              open < close
        else { return nil }

        var inner = String(raw[raw.index(after: open)..<close]).trimmingCharacters(in: .whitespacesAndNewlines)
        if (inner.hasPrefix("\"") && inner.hasSuffix("\"")) || (inner.hasPrefix("'") && inner.hasSuffix("'")) {
            inner = String(inner.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard inner.hasPrefix("#") else { return nil }
        let fragment = String(inner.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        return fragment.isEmpty ? nil : fragment
    }
}
