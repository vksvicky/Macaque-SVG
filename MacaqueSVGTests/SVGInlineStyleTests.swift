import XCTest
@testable import MacaqueSVG

final class SVGInlineStyleTests: XCTestCase {

    // MARK: - [Right] Are the Results Right?

    func testBasicFillParsing() {
        var style = SVGStyle()
        SVGInlineStyle.apply("fill: red", to: &style)
        XCTAssertEqual(style.fill, "red")
    }

    func testBasicStrokeParsing() {
        var style = SVGStyle()
        SVGInlineStyle.apply("stroke: blue", to: &style)
        XCTAssertEqual(style.stroke, "blue")
    }

    func testBasicStrokeWidthParsing() {
        var style = SVGStyle()
        SVGInlineStyle.apply("stroke-width: 3", to: &style)
        XCTAssertEqual(style.strokeWidth, 3)
    }

    func testBasicOpacityParsing() {
        var style = SVGStyle()
        SVGInlineStyle.apply("opacity: 0.5", to: &style)
        XCTAssertEqual(style.opacity, 0.5)
    }

    func testMultipleDeclarationsInOneString() {
        var style = SVGStyle()
        SVGInlineStyle.apply("fill: red; stroke: blue; opacity: 0.8", to: &style)

        XCTAssertEqual(style.fill, "red")
        XCTAssertEqual(style.stroke, "blue")
        XCTAssertEqual(style.opacity, 0.8)
    }

    func testStopColorMapsToFill() {
        var style = SVGStyle()
        SVGInlineStyle.apply("stop-color: #ff0000", to: &style)
        XCTAssertEqual(style.fill, "#ff0000")
    }

    func testStopOpacityMapsToOpacity() {
        var style = SVGStyle()
        SVGInlineStyle.apply("stop-opacity: 0.3", to: &style)
        XCTAssertEqual(style.opacity, 0.3)
    }

    // MARK: - [B] Boundary Conditions

    func testEmptyStyleString() {
        var style = SVGStyle()
        SVGInlineStyle.apply("", to: &style)

        XCTAssertNil(style.fill)
        XCTAssertNil(style.stroke)
        XCTAssertNil(style.strokeWidth)
        XCTAssertNil(style.opacity)
    }

    func testNilStyleString() {
        var style = SVGStyle()
        SVGInlineStyle.apply(nil, to: &style)

        XCTAssertNil(style.fill)
        XCTAssertNil(style.stroke)
    }

    func testMissingColonSkipsDeclaration() {
        var style = SVGStyle()
        SVGInlineStyle.apply("fill red", to: &style)
        XCTAssertNil(style.fill, "Missing colon should skip the declaration")
    }

    func testMissingValueAfterColon() {
        var style = SVGStyle()
        SVGInlineStyle.apply("fill:", to: &style)
        XCTAssertNil(style.fill, "Empty value after colon should be ignored")
    }

    func testTrailingSemicolon() {
        var style = SVGStyle()
        SVGInlineStyle.apply("fill: green;", to: &style)
        XCTAssertEqual(style.fill, "green")
    }

    func testImportantIsStripped() {
        var style = SVGStyle()
        SVGInlineStyle.apply("fill: red !important", to: &style)
        XCTAssertEqual(style.fill, "red")
    }

    func testImportantCaseInsensitive() {
        var style = SVGStyle()
        SVGInlineStyle.apply("fill: blue !IMPORTANT", to: &style)
        XCTAssertEqual(style.fill, "blue")
    }

    func testPxSuffixOnStrokeWidth() {
        var style = SVGStyle()
        SVGInlineStyle.apply("stroke-width: 5px", to: &style)
        XCTAssertEqual(style.strokeWidth, 5)
    }

    // MARK: - [E] Error Conditions

    func testUnknownCSSPropertiesAreIgnored() {
        var style = SVGStyle()
        SVGInlineStyle.apply("font-size: 14px; display: none; fill: red", to: &style)

        XCTAssertEqual(style.fill, "red")
        XCTAssertNil(style.stroke)
        XCTAssertNil(style.strokeWidth)
    }

    func testPercentStrokeWidthReturnsNil() {
        var style = SVGStyle()
        SVGInlineStyle.apply("stroke-width: 50%", to: &style)
        XCTAssertNil(style.strokeWidth, "Percent stroke-width should return nil")
    }

    func testWhitespaceOnlyStyleString() {
        var style = SVGStyle()
        SVGInlineStyle.apply("   ", to: &style)

        XCTAssertNil(style.fill)
    }

    func testExtraWhitespaceAroundDeclarations() {
        var style = SVGStyle()
        SVGInlineStyle.apply("  fill :  red  ;  stroke : blue  ", to: &style)

        XCTAssertEqual(style.fill, "red")
        XCTAssertEqual(style.stroke, "blue")
    }
}
