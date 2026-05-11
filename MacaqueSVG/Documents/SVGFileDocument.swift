import SwiftUI
import UniformTypeIdentifiers

struct SVGFileDocument: FileDocument {
    static let emptyTemplate = #"""
    <?xml version="1.0" encoding="UTF-8"?>
    <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">
    </svg>
    """#

    static var readableContentTypes: [UTType] { [.svgDocument, .macaqueCompressedSVG] }
    static var writableContentTypes: [UTType] { [.svgDocument, .macaqueCompressedSVG] }

    var svgSource: String

    init() {
        svgSource = Self.emptyTemplate
    }

    init(svgSource: String) {
        self.svgSource = svgSource
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try SVGIncomingDataValidator.validateContentTypeHint(configuration.contentType)

        let payload: Data
        if SVGZGzipCodec.isGzipMagic(data) {
            do {
                payload = try SVGZGzipCodec.decompress(data)
            } catch let err as SVGZGzipCodec.CodecError {
                throw SVGFileDocumentError.gzipReadFailed(err.presentation)
            } catch {
                throw SVGFileDocumentError.gzipReadFailed(error.localizedDescription)
            }
        } else {
            try SVGIncomingDataValidator.validateBinarySignatures(data)
            payload = data
        }

        guard let text = String(data: payload, encoding: .utf8) else {
            throw SVGFileDocumentError.notMarkupText
        }
        try SVGIncomingDataValidator.validateLooksLikeSVGMarkup(text)
        svgSource = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let utf8 = svgSource.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        let outData: Data
        if Self.shouldWriteCompressed(configuration: configuration) {
            do {
                outData = try SVGZGzipCodec.compress(utf8)
            } catch let err as SVGZGzipCodec.CodecError {
                throw SVGFileDocumentError.gzipWriteFailed(err.presentation)
            } catch {
                throw SVGFileDocumentError.gzipWriteFailed(error.localizedDescription)
            }
        } else {
            outData = utf8
        }
        return FileWrapper(regularFileWithContents: outData)
    }

    private static func shouldWriteCompressed(configuration: WriteConfiguration) -> Bool {
        if configuration.contentType.conforms(to: .macaqueCompressedSVG) {
            return true
        }
        if configuration.contentType.preferredFilenameExtension == "svgz" {
            return true
        }
        if let name = configuration.existingFile?.preferredFilename,
           (name as NSString).pathExtension.lowercased() == "svgz" {
            return true
        }
        return false
    }
}
