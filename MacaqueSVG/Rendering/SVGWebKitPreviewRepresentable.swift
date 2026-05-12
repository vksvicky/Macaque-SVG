import AppKit
import SwiftUI
import WebKit

/// WKWebView subclass that is transparent to the event system.
/// It renders SVG content but does not intercept any user input,
/// allowing SwiftUI gestures on parent views to work normally.
final class RenderOnlyWebView: WKWebView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

/// Renders the raw SVG markup through WebKit so layout matches Safari (including `<textPath>`).
/// External `<image href="…">` references are inlined as data URIs so the sandboxed WebContent
/// process never needs file system access.
@MainActor
struct SVGWebKitPreviewRepresentable: NSViewRepresentable {
    let svgSource: String
    let assetBaseURL: URL?
    @Environment(\.colorScheme) private var colorScheme

    final class Coordinator {
        var lastSVGHash: Int?
        var lastDark: Bool?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> RenderOnlyWebView {
        let config = WKWebViewConfiguration()
        let prefs = WKWebpagePreferences()
        prefs.preferredContentMode = .desktop
        config.defaultWebpagePreferences = prefs
        let webView = RenderOnlyWebView(frame: .zero, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = false
        return webView
    }

    func updateNSView(_ webView: RenderOnlyWebView, context: Context) {
        let isDark = colorScheme == .dark
        let hash = svgSource.hashValue
        let coordinator = context.coordinator
        if coordinator.lastSVGHash == hash, coordinator.lastDark == isDark {
            return
        }
        coordinator.lastSVGHash = hash
        coordinator.lastDark = isDark

        let inlinedSVG = Self.inlineExternalImages(svgSource: svgSource, assetBaseURL: assetBaseURL)

        let scheme = isDark ? "dark" : "light"
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="color-scheme" content="\(scheme)">
        <style>
        * { margin:0; padding:0; }
        html, body { width:100%; height:100%; overflow:hidden; background:transparent; }
        body { display:flex; align-items:center; justify-content:center; }
        svg { max-width:100%; max-height:100%; }
        </style>
        </head>
        <body>
        \(inlinedSVG)
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    /// Replace `href="relative/path.png"` (and `xlink:href`) in `<image>` elements with inline
    /// `data:image/…;base64,…` so WebKit never needs file access.
    private static func inlineExternalImages(svgSource: String, assetBaseURL: URL?) -> String {
        guard assetBaseURL != nil else { return svgSource }
        var result = svgSource

        let hrefPattern = try? NSRegularExpression(
            pattern: #"(<image\b[^>]*?\b(?:xlink:)?href\s*=\s*")([^"]+)(")"#,
            options: [.dotMatchesLineSeparators]
        )
        guard let regex = hrefPattern else { return svgSource }

        let nsSource = result as NSString
        let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsSource.length))

        var offset = 0
        for match in matches {
            guard match.numberOfRanges == 4 else { continue }
            let hrefRange = NSRange(location: match.range(at: 2).location + offset,
                                    length: match.range(at: 2).length)
            let href = (result as NSString).substring(with: hrefRange)

            if href.lowercased().hasPrefix("data:") { continue }
            if href.hasPrefix("http://") || href.hasPrefix("https://") { continue }

            guard let dataURI = Self.dataURI(forHref: href, assetBaseURL: assetBaseURL) else { continue }

            let mutable = NSMutableString(string: result)
            mutable.replaceCharacters(in: hrefRange, with: dataURI)
            let lengthDelta = dataURI.count - hrefRange.length
            offset += lengthDelta
            result = mutable as String
        }
        return result
    }

    private static func dataURI(forHref href: String, assetBaseURL: URL?) -> String? {
        guard let url = SVGHrefParsing.resolvedFileURL(href: href, assetBaseDirectory: assetBaseURL) else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        let ext = url.pathExtension.lowercased()
        let mime: String
        switch ext {
        case "png": mime = "image/png"
        case "jpg", "jpeg": mime = "image/jpeg"
        case "gif": mime = "image/gif"
        case "webp": mime = "image/webp"
        case "svg": mime = "image/svg+xml"
        default: mime = "application/octet-stream"
        }
        return "data:\(mime);base64,\(data.base64EncodedString())"
    }
}
