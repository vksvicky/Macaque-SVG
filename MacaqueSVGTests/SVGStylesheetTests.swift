import XCTest
@testable import MacaqueSVG

final class SVGStylesheetTests: XCTestCase {

    // MARK: - [Right] Are the Results Right?

    func testClassSelectorAppliesFill() {
        var sheet = SVGStylesheet.empty
        sheet.append(css: ".highlight { fill: red }")

        var style = SVGStyle()
        sheet.apply(to: &style, classList: "highlight", elementId: nil)

        XCTAssertEqual(style.fill, "red")
    }

    func testIdSelectorAppliesStyles() {
        var sheet = SVGStylesheet.empty
        sheet.append(css: "#logo { stroke: blue }")

        var style = SVGStyle()
        sheet.apply(to: &style, classList: nil, elementId: "logo")

        XCTAssertEqual(style.stroke, "blue")
    }

    func testMultipleRulesAppliedInOrder() {
        var sheet = SVGStylesheet.empty
        sheet.append(css: ".a { fill: red } .a { fill: green }")

        var style = SVGStyle()
        sheet.apply(to: &style, classList: "a", elementId: nil)

        XCTAssertEqual(style.fill, "green", "Later rule should overwrite earlier one")
    }

    func testClassAndIdRulesApplyTogether() {
        var sheet = SVGStylesheet.empty
        sheet.append(css: ".bg { fill: red } #main { stroke: blue }")

        var style = SVGStyle()
        sheet.apply(to: &style, classList: "bg", elementId: "main")

        XCTAssertEqual(style.fill, "red")
        XCTAssertEqual(style.stroke, "blue")
    }

    func testMultipleClassesOnElement() {
        var sheet = SVGStylesheet.empty
        sheet.append(css: ".a { fill: red } .b { stroke: green }")

        var style = SVGStyle()
        sheet.apply(to: &style, classList: "a b", elementId: nil)

        XCTAssertEqual(style.fill, "red")
        XCTAssertEqual(style.stroke, "green")
    }

    // MARK: - [B] Boundary Conditions

    func testEmptyStylesheetDoesNothing() {
        let sheet = SVGStylesheet.empty
        var style = SVGStyle()
        sheet.apply(to: &style, classList: "x", elementId: "y")

        XCTAssertNil(style.fill)
        XCTAssertNil(style.stroke)
    }

    func testAppendEmptyCSSText() {
        var sheet = SVGStylesheet.empty
        sheet.append(css: "")

        var style = SVGStyle()
        sheet.apply(to: &style, classList: "x", elementId: nil)

        XCTAssertNil(style.fill)
    }

    func testMalformedCSSMissingBraces() {
        var sheet = SVGStylesheet.empty
        sheet.append(css: ".broken fill: red")

        var style = SVGStyle()
        sheet.apply(to: &style, classList: "broken", elementId: nil)

        XCTAssertNil(style.fill, "Malformed CSS without braces should be ignored")
    }

    func testMalformedCSSMissingSelector() {
        var sheet = SVGStylesheet.empty
        sheet.append(css: "{ fill: red }")

        var style = SVGStyle()
        sheet.apply(to: &style, classList: nil, elementId: nil)

        XCTAssertNil(style.fill, "CSS without a class/id selector should not match")
    }

    func testCSSCommentsAreStripped() {
        var sheet = SVGStylesheet.empty
        sheet.append(css: "/* comment */ .item { fill: purple } /* end */")

        var style = SVGStyle()
        sheet.apply(to: &style, classList: "item", elementId: nil)

        XCTAssertEqual(style.fill, "purple")
    }

    func testNestedLookingComments() {
        var sheet = SVGStylesheet.empty
        sheet.append(css: ".x { /* fill: red */ fill: blue }")

        var style = SVGStyle()
        sheet.apply(to: &style, classList: "x", elementId: nil)

        XCTAssertEqual(style.fill, "blue")
    }

    // MARK: - [I] Inverse / Re-apply

    func testApplyThenReApplyOverridesPreviousValues() {
        var sheet = SVGStylesheet.empty
        sheet.append(css: ".a { fill: red }")

        var style = SVGStyle()
        sheet.apply(to: &style, classList: "a", elementId: nil)
        XCTAssertEqual(style.fill, "red")

        var sheet2 = SVGStylesheet.empty
        sheet2.append(css: ".a { fill: blue }")
        sheet2.apply(to: &style, classList: "a", elementId: nil)

        XCTAssertEqual(style.fill, "blue")
    }

    // MARK: - [E] Error Conditions

    func testSelectorWithNoMatchingClassIsIgnored() {
        var sheet = SVGStylesheet.empty
        sheet.append(css: ".no-match { fill: red }")

        var style = SVGStyle()
        sheet.apply(to: &style, classList: "other", elementId: nil)

        XCTAssertNil(style.fill)
    }

    func testSelectorWithNoMatchingIdIsIgnored() {
        var sheet = SVGStylesheet.empty
        sheet.append(css: "#nope { fill: red }")

        var style = SVGStyle()
        sheet.apply(to: &style, classList: nil, elementId: "different")

        XCTAssertNil(style.fill)
    }

    func testNilClassListAndElementId() {
        var sheet = SVGStylesheet.empty
        sheet.append(css: ".a { fill: red } #b { fill: blue }")

        var style = SVGStyle()
        sheet.apply(to: &style, classList: nil, elementId: nil)

        XCTAssertNil(style.fill)
    }

    func testHyphenatedClassSelector() {
        var sheet = SVGStylesheet.empty
        sheet.append(css: ".my-class { fill: orange }")

        var style = SVGStyle()
        sheet.apply(to: &style, classList: "my-class", elementId: nil)

        XCTAssertEqual(style.fill, "orange")
    }

    func testSelectorIsCaseInsensitive() {
        var sheet = SVGStylesheet.empty
        sheet.append(css: ".MyClass { fill: teal }")

        var style = SVGStyle()
        sheet.apply(to: &style, classList: "myclass", elementId: nil)

        XCTAssertEqual(style.fill, "teal")
    }
}
