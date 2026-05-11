import XCTest

@testable import MacaqueSVG

final class SVGBitmapDecoderTests: XCTestCase {
    func testDecodeTinyBase64PNG() {
        let b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        let href = "data:image/png;base64,\(b64)"
        XCTAssertNotNil(SVGBitmapDecoder.nsImage(fromHref: href))
    }

    func testRejectsNonDataHref() {
        XCTAssertNil(SVGBitmapDecoder.nsImage(fromHref: "https://example.com/x.png"))
    }
}
