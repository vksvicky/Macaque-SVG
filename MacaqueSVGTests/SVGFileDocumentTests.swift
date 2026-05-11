import XCTest

@testable import MacaqueSVG

final class SVGFileDocumentTests: XCTestCase {
    func testDefaultTemplateParses() throws {
        let document = SVGFileDocument()
        let parsed = try SVGParser().parse(string: document.svgSource)
        XCTAssertTrue(parsed.root.children.isEmpty)
    }

    func testCustomSourcePreservesUTF8Bytes() throws {
        let source = "<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>\n"
        let document = SVGFileDocument(svgSource: source)
        let data = try XCTUnwrap(document.svgSource.data(using: .utf8))
        let decoded = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertEqual(decoded, source)
    }

    func testGzipSVGPayloadPassesMarkupValidation() throws {
        let markup = "<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>"
        let gzipped = try SVGZGzipCodec.compress(Data(markup.utf8))
        let payload = try SVGZGzipCodec.decompress(gzipped)
        try SVGIncomingDataValidator.validateBinarySignatures(payload)
        let text = try XCTUnwrap(String(data: payload, encoding: .utf8))
        try SVGIncomingDataValidator.validateLooksLikeSVGMarkup(text)
    }
}
