import XCTest
@testable import MacaqueSVG

final class SVGHrefParsingTests: XCTestCase {

    // MARK: - [Right] fragmentId

    func testHashIdReturnsId() {
        XCTAssertEqual(SVGHrefParsing.fragmentId(from: "#myGradient"), "myGradient")
    }

    func testUrlHashIdReturnsId() {
        XCTAssertEqual(SVGHrefParsing.fragmentId(from: "file.svg#logo"), "logo")
    }

    func testFragmentIdTrimsWhitespace() {
        XCTAssertEqual(SVGHrefParsing.fragmentId(from: "  #spaced  "), "spaced")
    }

    // MARK: - [B] Boundary Conditions for fragmentId

    func testEmptyStringReturnsNil() {
        XCTAssertNil(SVGHrefParsing.fragmentId(from: ""))
    }

    func testWhitespaceOnlyReturnsNil() {
        XCTAssertNil(SVGHrefParsing.fragmentId(from: "   "))
    }

    func testNoHashCharacterReturnsNil() {
        XCTAssertNil(SVGHrefParsing.fragmentId(from: "nohash"))
    }

    func testHashAtEndWithNoId() {
        let result = SVGHrefParsing.fragmentId(from: "#")
        XCTAssertEqual(result, "", "Hash with nothing after it returns empty string")
    }

    func testHashAtEndOfUrl() {
        let result = SVGHrefParsing.fragmentId(from: "file.svg#")
        XCTAssertEqual(result, "")
    }

    // MARK: - [Right] resolvedFileURL

    func testResolvedFileURLWithRelativePath() {
        let base = URL(fileURLWithPath: "/Users/test/documents/")
        let result = SVGHrefParsing.resolvedFileURL(href: "image.png", assetBaseDirectory: base)

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.path.contains("image.png") ?? false)
    }

    func testResolvedFileURLWithAbsolutePath() {
        let result = SVGHrefParsing.resolvedFileURL(href: "/tmp/image.png", assetBaseDirectory: nil)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.path, "/tmp/image.png")
    }

    func testResolvedFileURLNilBase() {
        let result = SVGHrefParsing.resolvedFileURL(href: "relative.png", assetBaseDirectory: nil)
        XCTAssertNil(result, "Relative path without base directory should return nil")
    }

    // MARK: - [E] Error Conditions for resolvedFileURL

    func testDataURLReturnsNilForFileResolution() {
        let base = URL(fileURLWithPath: "/tmp/")
        let result = SVGHrefParsing.resolvedFileURL(href: "data:image/png;base64,abc", assetBaseDirectory: base)
        XCTAssertNil(result)
    }

    func testDataURLCaseInsensitive() {
        let base = URL(fileURLWithPath: "/tmp/")
        let result = SVGHrefParsing.resolvedFileURL(href: "DATA:image/png;base64,xyz", assetBaseDirectory: base)
        XCTAssertNil(result)
    }

    func testHttpURLReturnsNilForFileResolution() {
        let base = URL(fileURLWithPath: "/tmp/")
        let result = SVGHrefParsing.resolvedFileURL(href: "http://example.com/image.png", assetBaseDirectory: base)
        XCTAssertNil(result)
    }

    func testHttpsURLReturnsNilForFileResolution() {
        let base = URL(fileURLWithPath: "/tmp/")
        let result = SVGHrefParsing.resolvedFileURL(href: "https://example.com/image.png", assetBaseDirectory: base)
        XCTAssertNil(result)
    }

    func testEmptyHrefReturnsNilForFileResolution() {
        let base = URL(fileURLWithPath: "/tmp/")
        let result = SVGHrefParsing.resolvedFileURL(href: "", assetBaseDirectory: base)
        XCTAssertNil(result)
    }

    func testWhitespaceHrefReturnsNilForFileResolution() {
        let base = URL(fileURLWithPath: "/tmp/")
        let result = SVGHrefParsing.resolvedFileURL(href: "   ", assetBaseDirectory: base)
        XCTAssertNil(result)
    }
}
