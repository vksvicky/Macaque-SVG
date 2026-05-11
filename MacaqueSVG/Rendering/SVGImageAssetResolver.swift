import AppKit
import Foundation

@MainActor
enum SVGImageAssetResolver {
    /// Decodes `<image href>` file / nested-SVG references so Canvas drawing stays lightweight.
    static func warmRasterCaches(in document: SVGDocument) {
        func walk(_ element: SVGElement) {
            if let image = element as? SVGImage {
                image.warmRaster(assetBaseDirectory: document.assetBaseDirectory)
            }
            if let group = element as? SVGGroup {
                for child in group.children {
                    walk(child)
                }
            }
        }
        for child in document.root.children {
            walk(child)
        }
    }
}
