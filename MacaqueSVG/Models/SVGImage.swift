import AppKit
import Foundation

/// Embedded or linked raster (`<image>`).
final class SVGImage: SVGElement {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    /// Raw `href` / `xlink:href` value (e.g. `data:image/png;base64,…` or `../icon.svg`).
    var href: String
    var preserveAspectRatio: String?
    private var cachedDataURIImage: NSImage?
    /// Populated by `warmRaster` for file / nested-SVG `href`.
    private(set) var rasterDisplayImage: NSImage?

    init(
        x: CGFloat = 0,
        y: CGFloat = 0,
        width: CGFloat = 0,
        height: CGFloat = 0,
        href: String = "",
        svgId: String? = nil,
        transform: CGAffineTransform = .identity,
        style: SVGStyle = SVGStyle()
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.href = href
        super.init(svgId: svgId, transform: transform, style: style)
    }

    func clearRasterCache() {
        rasterDisplayImage = nil
        cachedDataURIImage = nil
    }

    /// Loads `data:` URIs, relative files, or nested `.svg` references (rasterized). Call from the main actor.
    @MainActor
    func warmRaster(assetBaseDirectory: URL?) {
        if rasterDisplayImage != nil { return }
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if trimmed.lowercased().hasPrefix("data:") {
            if let img = SVGBitmapDecoder.nsImage(fromHref: trimmed) {
                rasterDisplayImage = img
            }
            return
        }

        guard let url = SVGHrefParsing.resolvedFileURL(href: trimmed, assetBaseDirectory: assetBaseDirectory) else {
            return
        }

        if url.pathExtension.lowercased() == "svg" {
            guard let str = try? String(contentsOf: url, encoding: .utf8),
                  let nested = try? SVGParser().parse(
                      string: str,
                      assetBaseDirectory: url.deletingLastPathComponent()
                  )
            else { return }
            let size = CGSize(width: max(width, 1), height: max(height, 1))
            rasterDisplayImage = SVGDocumentRasterizer.rasterize(nested, pixelSize: size)
        } else {
            rasterDisplayImage = SVGBitmapDecoder.nsImage(contentsOfFileURL: url)
        }
    }

    /// Inline `data:` bitmaps (no file base required).
    func decodedDataURIImage() -> NSImage? {
        if let cachedDataURIImage { return cachedDataURIImage }
        guard let img = SVGBitmapDecoder.nsImage(fromHref: href) else { return nil }
        cachedDataURIImage = img
        return img
    }

    /// Bitmap for Canvas drawing (uses warmed file / nested-SVG cache or an inline `data:` image).
    /// Falls back to loading from disk synchronously if the warm cache was not populated.
    func displayBitmap(assetBaseDirectory: URL?) -> NSImage? {
        if let rasterDisplayImage { return rasterDisplayImage }
        if let dataImage = decodedDataURIImage() { return dataImage }
        loadRasterSync(assetBaseDirectory: assetBaseDirectory)
        return rasterDisplayImage
    }

    /// Synchronous file load fallback when `warmRaster` was not called beforehand.
    private func loadRasterSync(assetBaseDirectory: URL?) {
        guard rasterDisplayImage == nil else { return }
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.lowercased().hasPrefix("data:") else { return }
        guard let url = SVGHrefParsing.resolvedFileURL(href: trimmed, assetBaseDirectory: assetBaseDirectory) else {
            return
        }
        if url.pathExtension.lowercased() == "svg" {
            return
        }
        rasterDisplayImage = SVGBitmapDecoder.nsImage(contentsOfFileURL: url)
    }
}
