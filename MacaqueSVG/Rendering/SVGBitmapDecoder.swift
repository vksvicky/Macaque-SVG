import AppKit
import Foundation

/// Decodes raster data referenced by `<image href="…">` (currently `data:` URIs with base64 payloads).
enum SVGBitmapDecoder {
    static func nsImage(fromHref href: String) -> NSImage? {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.lowercased().hasPrefix("data:") {
            return nsImage(fromDataURI: trimmed)
        }
        return nil
    }

    static func nsImage(contentsOfFileURL url: URL) -> NSImage? {
        NSImage(contentsOf: url)
    }

    private static func nsImage(fromDataURI uri: String) -> NSImage? {
        guard let comma = uri.firstIndex(of: ",") else { return nil }
        let header = String(uri[..<comma]).lowercased()
        let payload = String(uri[uri.index(after: comma)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard header.contains("base64") else { return nil }
        guard let data = Data(base64Encoded: payload, options: [.ignoreUnknownCharacters]) else {
            return nil
        }
        return NSImage(data: data)
    }
}
