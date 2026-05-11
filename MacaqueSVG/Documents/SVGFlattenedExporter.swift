import Foundation

/// Replaces external `<image href>` references in the source string with `data:` URIs.
enum SVGFlattenedExporter {
    static func flattenSource(_ svgSource: String, parsed: SVGDocument) -> String {
        var seen = Set<String>()
        var replacements: [(original: String, dataHref: String)] = []

        func walk(_ element: SVGElement) {
            if let image = element as? SVGImage {
                let raw = image.href.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !raw.isEmpty, !raw.lowercased().hasPrefix("data:") else {
                    return
                }
                guard seen.insert(raw).inserted else { return }
                guard let url = SVGHrefParsing.resolvedFileURL(href: raw, assetBaseDirectory: parsed.assetBaseDirectory),
                      let data = try? Data(contentsOf: url)
                else {
                    return
                }
                let mime = mimeType(for: url)
                let b64 = data.base64EncodedString()
                let dataHref = "data:\(mime);base64,\(b64)"
                replacements.append((original: raw, dataHref: dataHref))
            }
            if let group = element as? SVGGroup {
                for child in group.children {
                    walk(child)
                }
            }
        }
        walk(parsed.root)

        var result = svgSource
        for pair in replacements {
            result = result.replacingOccurrences(
                of: "href=\"\(pair.original)\"",
                with: "href=\"\(pair.dataHref)\""
            )
            result = result.replacingOccurrences(
                of: "href='\(pair.original)'",
                with: "href='\(pair.dataHref)'"
            )
            result = result.replacingOccurrences(
                of: "xlink:href=\"\(pair.original)\"",
                with: "xlink:href=\"\(pair.dataHref)\""
            )
        }
        return result
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "svg": return "image/svg+xml"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        default: return "image/png"
        }
    }
}
