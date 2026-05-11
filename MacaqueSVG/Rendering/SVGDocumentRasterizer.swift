import AppKit
import SwiftUI

@MainActor
enum SVGDocumentRasterizer {
    /// Renders the document preview into a bitmap at the requested pixel size.
    static func rasterize(_ document: SVGDocument, pixelSize: CGSize) -> NSImage? {
        guard pixelSize.width >= 1, pixelSize.height >= 1 else { return nil }
        let renderer = ImageRenderer(content:
            SVGPreviewView(document: document, showsTransparencyGrid: false, useBrowserSVGRendering: false)
                .frame(width: pixelSize.width, height: pixelSize.height)
        )
        renderer.scale = 1
        renderer.isOpaque = false
        return renderer.nsImage
    }
}
