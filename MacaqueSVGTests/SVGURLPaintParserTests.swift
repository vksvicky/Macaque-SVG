import XCTest
@testable import MacaqueSVG

final class SVGURLPaintParserTests: XCTestCase {

    // MARK: - [Right] Are the Results Right?

    func testUrlHashGradientReturnsGradient() {
        XCTAssertEqual(SVGURLPaintParser.paintServerFragment(from: "url(#gradient)"), "gradient")
    }

    func testUrlSingleQuotedHashReturnsId() {
        XCTAssertEqual(SVGURLPaintParser.paintServerFragment(from: "url('#gradient')"), "gradient")
    }

    func testUrlDoubleQuotedHashReturnsId() {
        XCTAssertEqual(SVGURLPaintParser.paintServerFragment(from: "url(\"#gradient\")"), "gradient")
    }

    func testUrlWithWhitespaceInsideParens() {
        XCTAssertEqual(SVGURLPaintParser.paintServerFragment(from: "url( #myId )"), "myId")
    }

    func testUrlWithWhitespaceInsideQuotes() {
        XCTAssertEqual(SVGURLPaintParser.paintServerFragment(from: "url(' #spaced ')"), "spaced")
    }

    // MARK: - [B] Boundary Conditions

    func testNilReturnsNil() {
        XCTAssertNil(SVGURLPaintParser.paintServerFragment(from: nil))
    }

    func testEmptyStringReturnsNil() {
        XCTAssertNil(SVGURLPaintParser.paintServerFragment(from: ""))
    }

    func testWhitespaceOnlyReturnsNil() {
        XCTAssertNil(SVGURLPaintParser.paintServerFragment(from: "   "))
    }

    func testUrlEmptyParensReturnsNil() {
        XCTAssertNil(SVGURLPaintParser.paintServerFragment(from: "url()"))
    }

    func testUrlJustHashReturnsNil() {
        XCTAssertNil(SVGURLPaintParser.paintServerFragment(from: "url(#)"))
    }

    func testUrlQuotedEmptyHashReturnsNil() {
        XCTAssertNil(SVGURLPaintParser.paintServerFragment(from: "url('#')"))
    }

    // MARK: - [E] Error Conditions

    func testNoUrlPrefixReturnsNil() {
        XCTAssertNil(SVGURLPaintParser.paintServerFragment(from: "#gradient"))
    }

    func testPlainTextReturnsNil() {
        XCTAssertNil(SVGURLPaintParser.paintServerFragment(from: "red"))
    }

    func testNoHashInsideUrlReturnsNil() {
        XCTAssertNil(SVGURLPaintParser.paintServerFragment(from: "url(gradient)"))
    }

    func testUrlCaseInsensitivePrefix() {
        XCTAssertEqual(SVGURLPaintParser.paintServerFragment(from: "URL(#thing)"), "thing")
    }

    func testUrlMissingClosingParenReturnsNil() {
        XCTAssertNil(SVGURLPaintParser.paintServerFragment(from: "url(#broken"))
    }
}
