import XCTest

@testable import MacaqueSVG

final class SVGIncomingDataValidatorTests: XCTestCase {
    func testPNGSignatureRejected() {
        let pngHeader: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]
        let data = Data(pngHeader)
        XCTAssertThrowsError(try SVGIncomingDataValidator.validateBinarySignatures(data)) { error in
            XCTAssertTrue(error is SVGFileDocumentError)
        }
    }

    func testJPEGSignatureRejected() {
        let data = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00])
        XCTAssertThrowsError(try SVGIncomingDataValidator.validateBinarySignatures(data))
    }

    func testMinimalSVGDataPassesBinaryCheck() throws {
        let data = try XCTUnwrap("<svg xmlns=\"http://www.w3.org/2000/svg\"/>".data(using: .utf8))
        try SVGIncomingDataValidator.validateBinarySignatures(data)
        try SVGIncomingDataValidator.validateLooksLikeSVGMarkup(String(data: data, encoding: .utf8)!)
    }
}
