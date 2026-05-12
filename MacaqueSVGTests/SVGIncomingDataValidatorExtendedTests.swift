import UniformTypeIdentifiers
import XCTest

@testable import MacaqueSVG

final class SVGIncomingDataValidatorExtendedTests: XCTestCase {

    // MARK: - [Right] Are the Results Right?

    func testValidSVGStringPassesMarkupCheck() throws {
        try SVGIncomingDataValidator.validateLooksLikeSVGMarkup(
            "<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>"
        )
    }

    func testXMLDeclarationPrefixPassesMarkupCheck() throws {
        try SVGIncomingDataValidator.validateLooksLikeSVGMarkup(
            "<?xml version=\"1.0\"?><svg xmlns=\"http://www.w3.org/2000/svg\"/>"
        )
    }

    // MARK: - [B] Boundary Conditions

    func testBOMPrefixedSVGPasses() throws {
        let bom = "\u{FEFF}<svg xmlns=\"http://www.w3.org/2000/svg\"/>"
        try SVGIncomingDataValidator.validateLooksLikeSVGMarkup(bom)
    }

    func testWhitespaceBeforeSVGPasses() throws {
        try SVGIncomingDataValidator.validateLooksLikeSVGMarkup(
            "   \n  <svg xmlns=\"http://www.w3.org/2000/svg\"/>"
        )
    }

    func testEmptyStringFailsMarkupCheck() {
        XCTAssertThrowsError(try SVGIncomingDataValidator.validateLooksLikeSVGMarkup("")) { error in
            XCTAssertEqual(error as? SVGFileDocumentError, .notMarkupText)
        }
    }

    func testWhitespaceOnlyFailsMarkupCheck() {
        XCTAssertThrowsError(try SVGIncomingDataValidator.validateLooksLikeSVGMarkup("   \n\t  ")) { error in
            XCTAssertEqual(error as? SVGFileDocumentError, .notMarkupText)
        }
    }

    func testPlainTextFailsMarkupCheck() {
        XCTAssertThrowsError(try SVGIncomingDataValidator.validateLooksLikeSVGMarkup("Hello world")) { error in
            XCTAssertEqual(error as? SVGFileDocumentError, .notMarkupText)
        }
    }

    // MARK: - Binary Signature Tests

    func testGIFSignatureRejected() {
        let data = Data("GIF89a".utf8) + Data(repeating: 0, count: 10)
        XCTAssertThrowsError(try SVGIncomingDataValidator.validateBinarySignatures(data))
    }

    func testGIF87aSignatureRejected() {
        let data = Data("GIF87a".utf8) + Data(repeating: 0, count: 10)
        XCTAssertThrowsError(try SVGIncomingDataValidator.validateBinarySignatures(data))
    }

    func testWebPSignatureRejected() {
        var data = Data("RIFF".utf8)
        data.append(Data(repeating: 0, count: 4))
        data.append(Data("WEBP".utf8))
        XCTAssertThrowsError(try SVGIncomingDataValidator.validateBinarySignatures(data))
    }

    func testPDFSignatureRejected() {
        let data = Data("%PDF-1.4".utf8) + Data(repeating: 0, count: 10)
        XCTAssertThrowsError(try SVGIncomingDataValidator.validateBinarySignatures(data))
    }

    func testBMPSignatureRejected() {
        let data = Data([0x42, 0x4D, 0x00, 0x00])
        XCTAssertThrowsError(try SVGIncomingDataValidator.validateBinarySignatures(data))
    }

    func testEmptyDataPassesBinaryCheck() throws {
        try SVGIncomingDataValidator.validateBinarySignatures(Data())
    }

    func testSingleBytePasses() throws {
        try SVGIncomingDataValidator.validateBinarySignatures(Data([0x3C]))
    }

    // MARK: - Content Type Validation

    func testPNGContentTypeRejected() {
        XCTAssertThrowsError(try SVGIncomingDataValidator.validateContentTypeHint(.png))
    }

    func testJPEGContentTypeRejected() {
        XCTAssertThrowsError(try SVGIncomingDataValidator.validateContentTypeHint(.jpeg))
    }

    func testNilContentTypePasses() throws {
        try SVGIncomingDataValidator.validateContentTypeHint(nil)
    }

    // MARK: - [C] Cross-Check

    func testErrorDescriptionsAreNonEmpty() {
        let errors: [SVGFileDocumentError] = [
            .rasterOrBinaryNotSVG("test"),
            .notMarkupText,
            .gzipReadFailed("reason"),
            .gzipWriteFailed("reason"),
        ]
        for error in errors {
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true, "\(error) has empty description")
        }
    }

    // MARK: - [I] Inverse Relationships

    func testSVGDataPassesBothChecks() throws {
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\"/>"
        let data = Data(svg.utf8)
        try SVGIncomingDataValidator.validateBinarySignatures(data)
        try SVGIncomingDataValidator.validateLooksLikeSVGMarkup(svg)
    }
}
