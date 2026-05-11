import AppKit
import CoreGraphics
import Foundation

@MainActor
enum SVGRasterPDFExporter {
    /// Rasterizes at `pixelSize` multiplied by `scale` (e.g. `2` for a 2× export).
    static func pngData(document: SVGDocument, pixelSize: CGSize, scale: CGFloat = 1) -> Data? {
        let scaled = CGSize(
            width: max(pixelSize.width * scale, 1),
            height: max(pixelSize.height * scale, 1)
        )
        guard let image = SVGDocumentRasterizer.rasterize(document, pixelSize: scaled) else { return nil }
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    static func pdfData(document: SVGDocument, pixelSize: CGSize, scale: CGFloat = 1) -> Data? {
        let scaled = CGSize(
            width: max(pixelSize.width * scale, 1),
            height: max(pixelSize.height * scale, 1)
        )
        guard let image = SVGDocumentRasterizer.rasterize(document, pixelSize: scaled),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return nil
        }

        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: scaled)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else {
            return nil
        }

        ctx.beginPDFPage(nil)
        ctx.draw(cgImage, in: mediaBox)
        ctx.endPDFPage()
        ctx.closePDF()
        return data as Data
    }
}
