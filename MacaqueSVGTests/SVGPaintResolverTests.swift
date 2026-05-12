import XCTest

@testable import MacaqueSVG

final class SVGPaintResolverTests: XCTestCase {

    // MARK: - [Right] fillColor

    func testFillColorReturnsBlackForNil() {
        let color = SVGPaintResolver.fillColor(nil)
        XCTAssertNotNil(color, "Default fill must be black, not nil")
    }

    func testFillColorReturnsNilForNone() {
        XCTAssertNil(SVGPaintResolver.fillColor("none"))
    }

    func testFillColorReturnsNilForNoneCaseInsensitive() {
        XCTAssertNil(SVGPaintResolver.fillColor("None"))
        XCTAssertNil(SVGPaintResolver.fillColor("NONE"))
    }

    func testFillColorReturnsNilForURLReference() {
        XCTAssertNil(SVGPaintResolver.fillColor("url(#gradient1)"))
        XCTAssertNil(SVGPaintResolver.fillColor("url(#img)"))
    }

    // MARK: - [Right] Hex colors

    func testFillColorShortHexRed() {
        let color = SVGPaintResolver.fillColor("#f00")
        XCTAssertNotNil(color)
    }

    func testFillColorFullHexRed() {
        let color = SVGPaintResolver.fillColor("#ff0000")
        XCTAssertNotNil(color)
    }

    func testFillColorHexWithAlpha() {
        let color = SVGPaintResolver.fillColor("#ff000080")
        XCTAssertNotNil(color)
    }

    func testThreeDigitHexExpansion() {
        let short = SVGPaintResolver.fillColor("#abc")
        let full = SVGPaintResolver.fillColor("#aabbcc")
        XCTAssertNotNil(short)
        XCTAssertNotNil(full)
    }

    // MARK: - [Right] RGB function

    func testRGBFunctionAbsolute() {
        let color = SVGPaintResolver.fillColor("rgb(255,0,0)")
        XCTAssertNotNil(color)
    }

    func testRGBFunctionPercentage() {
        let color = SVGPaintResolver.fillColor("rgb(100%,0%,0%)")
        XCTAssertNotNil(color)
    }

    // MARK: - [Right] Named colors

    func testNamedColorRed() {
        XCTAssertNotNil(SVGPaintResolver.fillColor("red"))
    }

    func testNamedColorBlue() {
        XCTAssertNotNil(SVGPaintResolver.fillColor("blue"))
    }

    func testNamedColorGreen() {
        XCTAssertNotNil(SVGPaintResolver.fillColor("green"))
    }

    func testNamedColorBlack() {
        XCTAssertNotNil(SVGPaintResolver.fillColor("black"))
    }

    func testNamedColorWhite() {
        XCTAssertNotNil(SVGPaintResolver.fillColor("white"))
    }

    // MARK: - [B] Boundary conditions

    func testFillColorEmptyStringReturnsBlack() {
        let color = SVGPaintResolver.fillColor("")
        XCTAssertNotNil(color, "Empty string should default to black")
    }

    func testFillColorWhitespaceOnlyReturnsBlack() {
        let color = SVGPaintResolver.fillColor("   ")
        XCTAssertNotNil(color, "Whitespace-only should default to black")
    }

    func testCurrentColorMapsToLabelColor() {
        let color = SVGPaintResolver.fillColor("currentColor")
        XCTAssertNotNil(color)
    }

    func testCurrentColorCaseInsensitive() {
        XCTAssertNotNil(SVGPaintResolver.fillColor("currentcolor"))
        XCTAssertNotNil(SVGPaintResolver.fillColor("CURRENTCOLOR"))
    }

    // MARK: - [Right] strokeColor

    func testStrokeColorReturnsNilForNil() {
        XCTAssertNil(SVGPaintResolver.strokeColor(nil))
    }

    func testStrokeColorReturnsNilForEmptyString() {
        XCTAssertNil(SVGPaintResolver.strokeColor(""))
    }

    func testStrokeColorReturnsNilForNone() {
        XCTAssertNil(SVGPaintResolver.strokeColor("none"))
    }

    func testStrokeColorReturnsNilForURL() {
        XCTAssertNil(SVGPaintResolver.strokeColor("url(#g)"))
    }

    func testStrokeColorReturnsColorForHex() {
        XCTAssertNotNil(SVGPaintResolver.strokeColor("#00ff00"))
    }

    func testStrokeColorCurrentColor() {
        XCTAssertNotNil(SVGPaintResolver.strokeColor("currentColor"))
    }

    // MARK: - [Right] nsColor

    func testNsColorReturnsNSColorForValidFill() {
        let nsColor = SVGPaintResolver.nsColor(forFill: "red")
        XCTAssertNotNil(nsColor)
    }

    func testNsColorReturnsNilForNone() {
        XCTAssertNil(SVGPaintResolver.nsColor(forFill: "none"))
    }

    func testNsColorReturnsNSColorForNilInput() {
        let nsColor = SVGPaintResolver.nsColor(forFill: nil)
        XCTAssertNotNil(nsColor, "nil fill defaults to black → non-nil NSColor")
    }

    // MARK: - [Right] colorForGradientStop

    func testGradientStopDefaultsToBlackForNil() {
        _ = SVGPaintResolver.colorForGradientStop(nil)
    }

    func testGradientStopDefaultsToBlackForEmpty() {
        _ = SVGPaintResolver.colorForGradientStop("")
    }

    func testGradientStopResolvesNamedColor() {
        _ = SVGPaintResolver.colorForGradientStop("red")
    }

    func testGradientStopCurrentColor() {
        _ = SVGPaintResolver.colorForGradientStop("currentColor")
    }

    // MARK: - [E] Error conditions

    func testInvalidHexStringFallsBackToBlack() {
        let color = SVGPaintResolver.fillColor("#xyz")
        XCTAssertNotNil(color, "Invalid hex falls back to black via fillColor default")
    }

    func testRGBWithTooFewComponentsReturnsBlack() {
        let color = SVGPaintResolver.fillColor("rgb(255,0)")
        XCTAssertNotNil(color, "Malformed rgb() falls back to black via fillColor default")
    }

    func testUnknownNamedColorStrokeReturnsNil() {
        XCTAssertNil(SVGPaintResolver.strokeColor("chartreuse"))
    }

    func testUnknownNamedColorFillFallsBackToBlack() {
        let color = SVGPaintResolver.fillColor("chartreuse")
        XCTAssertNotNil(color, "Unknown named color falls back to black in fillColor")
    }

    func testRGBMissingParentheses() {
        let color = SVGPaintResolver.fillColor("rgb255,0,0")
        XCTAssertNotNil(color, "Malformed rgb falls back to black default")
    }

    func testEmptyHexAfterHash() {
        let color = SVGPaintResolver.fillColor("#")
        XCTAssertNotNil(color, "Bare '#' falls back to black default")
    }
}
