import Foundation

enum SVGHrefParsing {
    /// Resolves `#id` or `url#id` style fragment from `href` / `xlink:href`.
    static func fragmentId(from href: String) -> String? {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("#") {
            return String(trimmed.dropFirst())
        }
        if let hash = trimmed.firstIndex(of: "#") {
            return String(trimmed[trimmed.index(after: hash)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    /// Resolves a file URL for `href` relative to `assetBaseDirectory` (folder of the document).
    static func resolvedFileURL(href: String, assetBaseDirectory: URL?) -> URL? {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.lowercased().hasPrefix("data:") { return nil }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") { return nil }
        if trimmed.hasPrefix("/") {
            return URL(fileURLWithPath: trimmed)
        }
        guard let base = assetBaseDirectory else { return nil }
        return URL(string: trimmed, relativeTo: base)?.standardizedFileURL
    }
}
