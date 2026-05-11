import Foundation
import UniformTypeIdentifiers

enum SVGFileDocumentError: LocalizedError, Equatable {
    case rasterOrBinaryNotSVG(String)
    case notMarkupText
    case gzipReadFailed(String)
    case gzipWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case let .rasterOrBinaryNotSVG(message):
            return message
        case .notMarkupText:
            return "This file does not look like SVG or XML. Macaque SVG only opens .svg and .svgz documents."
        case let .gzipReadFailed(message):
            return "Could not decompress SVGZ: \(message)"
        case let .gzipWriteFailed(message):
            return "Could not compress SVGZ: \(message)"
        }
    }
}

enum SVGIncomingDataValidator {
    /// Rejects common raster/binary formats before string decoding (avoids mis-parsing PNG as Latin‑1 “text”).
    static func validateBinarySignatures(_ data: Data) throws {
        guard !data.isEmpty else { return }

        if data.count >= 8, data.prefix(8).elementsEqual([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            throw SVGFileDocumentError.rasterOrBinaryNotSVG(
                "This is a PNG image. Macaque SVG only opens vector SVG (.svg or .svgz) files."
            )
        }

        if data.count >= 3, data[0] == 0xFF, data[1] == 0xD8, data[2] == 0xFF {
            throw SVGFileDocumentError.rasterOrBinaryNotSVG(
                "This is a JPEG image. Macaque SVG only opens vector SVG (.svg or .svgz) files."
            )
        }

        if data.count >= 6 {
            let tag = data.prefix(6)
            if tag.elementsEqual("GIF87a".utf8) || tag.elementsEqual("GIF89a".utf8) {
                throw SVGFileDocumentError.rasterOrBinaryNotSVG(
                    "This is a GIF image. Macaque SVG only opens vector SVG (.svg or .svgz) files."
                )
            }
        }

        if data.count >= 12,
           data.prefix(4).elementsEqual("RIFF".utf8),
           data.subdata(in: 8..<12).elementsEqual("WEBP".utf8) {
            throw SVGFileDocumentError.rasterOrBinaryNotSVG(
                "This is a WebP image. Macaque SVG only opens vector SVG (.svg or .svgz) files."
            )
        }

        if data.count >= 4, data.prefix(4).elementsEqual("%PDF".utf8) {
            throw SVGFileDocumentError.rasterOrBinaryNotSVG(
                "This is a PDF file. Macaque SVG only opens vector SVG (.svg or .svgz) files."
            )
        }

        if data.count >= 2, data[0] == 0x42, data[1] == 0x4D {
            throw SVGFileDocumentError.rasterOrBinaryNotSVG(
                "This is a BMP image. Macaque SVG only opens vector SVG (.svg or .svgz) files."
            )
        }
    }

    /// Uses UTType when the system provides it (e.g. opening a PNG).
    static func validateContentTypeHint(_ contentType: UTType?) throws {
        guard let contentType else { return }

        if contentType.conforms(to: .macaqueCompressedSVG) {
            return
        }

        let rasterTypes: [UTType] = [.png, .jpeg, .gif, .webP, .tiff, .bmp, .ico, .heic, .heif]
        for raster in rasterTypes where contentType.conforms(to: raster) {
            let label = contentType.localizedDescription ?? contentType.identifier
            throw SVGFileDocumentError.rasterOrBinaryNotSVG(
                "This file is a raster image type (\(label)). Macaque SVG only opens vector SVG (.svg or .svgz) files."
            )
        }
    }

    /// After decoding as text, require plausible XML/SVG start (strips UTF‑8 BOM).
    static func validateLooksLikeSVGMarkup(_ text: String) throws {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("\u{FEFF}") {
            trimmed = String(trimmed.dropFirst())
        }
        guard trimmed.first == "<" else {
            throw SVGFileDocumentError.notMarkupText
        }
    }
}
