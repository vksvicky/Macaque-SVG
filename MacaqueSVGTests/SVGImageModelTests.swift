import XCTest

@testable import MacaqueSVG

final class SVGImageModelTests: XCTestCase {

    // MARK: - [Right] SVGImage init

    func testImageDefaults() {
        let image = SVGImage()
        XCTAssertEqual(image.x, 0)
        XCTAssertEqual(image.y, 0)
        XCTAssertEqual(image.width, 0)
        XCTAssertEqual(image.height, 0)
        XCTAssertEqual(image.href, "")
        XCTAssertNil(image.preserveAspectRatio)
    }

    func testImageWithValues() {
        let image = SVGImage(x: 10, y: 20, width: 100, height: 200, href: "image.png")
        XCTAssertEqual(image.x, 10)
        XCTAssertEqual(image.y, 20)
        XCTAssertEqual(image.width, 100)
        XCTAssertEqual(image.height, 200)
        XCTAssertEqual(image.href, "image.png")
    }

    // MARK: - [Right] decodedDataURIImage

    func testDecodedDataURIPNG() {
        let b64 =
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        let image = SVGImage(href: "data:image/png;base64,\(b64)")
        XCTAssertNotNil(image.decodedDataURIImage())
    }

    func testDecodedDataURICachesResult() {
        let b64 =
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        let image = SVGImage(href: "data:image/png;base64,\(b64)")
        let first = image.decodedDataURIImage()
        let second = image.decodedDataURIImage()
        XCTAssertTrue(first === second)
    }

    // MARK: - [B] Boundary Conditions

    func testDecodedDataURIEmptyHrefReturnsNil() {
        let image = SVGImage(href: "")
        XCTAssertNil(image.decodedDataURIImage())
    }

    func testDecodedDataURINonDataHrefReturnsNil() {
        let image = SVGImage(href: "https://example.com/img.png")
        XCTAssertNil(image.decodedDataURIImage())
    }

    func testDecodedDataURIInvalidBase64ReturnsNil() {
        let image = SVGImage(href: "data:image/png;base64,NOT_VALID_BASE64!!!")
        XCTAssertNil(image.decodedDataURIImage())
    }

    // MARK: - [Right] clearRasterCache

    func testClearRasterCacheResetsDecoded() {
        let b64 =
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        let image = SVGImage(href: "data:image/png;base64,\(b64)")
        _ = image.decodedDataURIImage()
        image.clearRasterCache()
        XCTAssertNil(image.rasterDisplayImage)
    }

    // MARK: - [Right] displayBitmap

    func testDisplayBitmapFallsBackToDataURI() {
        let b64 =
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        let image = SVGImage(href: "data:image/png;base64,\(b64)")
        XCTAssertNotNil(image.displayBitmap(assetBaseDirectory: nil))
    }

    // MARK: - [I] SVGImage is SVGElement

    func testImageIsElement() {
        let image = SVGImage(svgId: "img1")
        XCTAssertEqual(image.svgId, "img1")
        XCTAssertNotNil(image.nodeID)
    }
}
