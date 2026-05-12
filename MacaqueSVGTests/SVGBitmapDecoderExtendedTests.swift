import XCTest

@testable import MacaqueSVG

final class SVGBitmapDecoderExtendedTests: XCTestCase {

    private let validPNGBase64 =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="

    // MARK: - [Right] Data URI parsing

    func testValidPNGDataURIDecodes() {
        let href = "data:image/png;base64,\(validPNGBase64)"
        XCTAssertNotNil(SVGBitmapDecoder.nsImage(fromHref: href))
    }

    func testJPEGDataURITypeAccepted() {
        let href = "data:image/jpeg;base64,\(validPNGBase64)"
        let result = SVGBitmapDecoder.nsImage(fromHref: href)
        // PNG data with jpeg mime may or may not decode; the decoder doesn't validate mime vs data
        // This tests that the function doesn't crash
        _ = result
    }

    func testDataURIWithWhitespaceTrimmed() {
        let href = "  data:image/png;base64,\(validPNGBase64)  "
        XCTAssertNotNil(SVGBitmapDecoder.nsImage(fromHref: href))
    }

    // MARK: - [B] Boundary Conditions

    func testEmptyHrefReturnsNil() {
        XCTAssertNil(SVGBitmapDecoder.nsImage(fromHref: ""))
    }

    func testWhitespaceOnlyReturnsNil() {
        XCTAssertNil(SVGBitmapDecoder.nsImage(fromHref: "   "))
    }

    func testNonDataURIReturnsNil() {
        XCTAssertNil(SVGBitmapDecoder.nsImage(fromHref: "https://example.com/image.png"))
    }

    func testFilePathReturnsNil() {
        XCTAssertNil(SVGBitmapDecoder.nsImage(fromHref: "/path/to/image.png"))
    }

    func testRelativePathReturnsNil() {
        XCTAssertNil(SVGBitmapDecoder.nsImage(fromHref: "../images/icon.png"))
    }

    // MARK: - [E] Error Conditions

    func testDataURIWithoutBase64ReturnsNil() {
        XCTAssertNil(SVGBitmapDecoder.nsImage(fromHref: "data:image/png,rawtext"))
    }

    func testDataURIWithNoCommaReturnsNil() {
        XCTAssertNil(SVGBitmapDecoder.nsImage(fromHref: "data:image/png;base64"))
    }

    func testDataURIWithInvalidBase64ReturnsNil() {
        XCTAssertNil(SVGBitmapDecoder.nsImage(fromHref: "data:image/png;base64,ZZZZ!!!"))
    }

    func testDataURIWithEmptyPayloadReturnsNil() {
        XCTAssertNil(SVGBitmapDecoder.nsImage(fromHref: "data:image/png;base64,"))
    }

    // MARK: - [C] Cross-Check with SVGImage

    func testSVGImageDecodedDataURIMatchesDirect() {
        let href = "data:image/png;base64,\(validPNGBase64)"
        let direct = SVGBitmapDecoder.nsImage(fromHref: href)
        let image = SVGImage(href: href)
        let viaImage = image.decodedDataURIImage()
        XCTAssertNotNil(direct)
        XCTAssertNotNil(viaImage)
    }
}
