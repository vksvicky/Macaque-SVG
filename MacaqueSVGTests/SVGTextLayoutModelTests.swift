import XCTest

@testable import MacaqueSVG

final class SVGTextLayoutModelTests: XCTestCase {

    // MARK: - [Right] SVGTextBlock

    func testTextBlockDefaults() {
        let block = SVGTextBlock()
        XCTAssertEqual(block.x, 0)
        XCTAssertEqual(block.y, 0)
        XCTAssertEqual(block.plainText, "")
        XCTAssertNil(block.fontFamily)
        XCTAssertNil(block.fontSize)
        XCTAssertNil(block.fontWeightValue)
        XCTAssertNil(block.letterSpacing)
    }

    func testTextBlockWithValues() {
        let block = SVGTextBlock()
        block.x = 10
        block.y = 20
        block.plainText = "Hello"
        block.fontFamily = "Helvetica"
        block.fontSize = 14
        XCTAssertEqual(block.x, 10)
        XCTAssertEqual(block.y, 20)
        XCTAssertEqual(block.plainText, "Hello")
        XCTAssertEqual(block.fontFamily, "Helvetica")
        XCTAssertEqual(block.fontSize, 14)
    }

    // MARK: - [Right] SVGTextPath

    func testTextPathDefaults() {
        let textPath = SVGTextPath()
        XCTAssertEqual(textPath.pathHrefFragment, "")
        XCTAssertNil(textPath.startOffset)
        XCTAssertNil(textPath.textAnchor)
        XCTAssertNil(textPath.hostTextBlock)
        XCTAssertEqual(textPath.inlineText, "")
        XCTAssertNil(textPath.cachedRender)
    }

    func testTextPathWithValues() {
        let textPath = SVGTextPath()
        textPath.pathHrefFragment = "arc"
        textPath.startOffset = "50%"
        textPath.textAnchor = "middle"
        textPath.inlineText = "HELLO"
        XCTAssertEqual(textPath.pathHrefFragment, "arc")
        XCTAssertEqual(textPath.startOffset, "50%")
        XCTAssertEqual(textPath.textAnchor, "middle")
        XCTAssertEqual(textPath.inlineText, "HELLO")
    }

    // MARK: - [Right] SVGTSpanNode

    func testTSpanNodeDefaults() {
        let span = SVGTSpanNode()
        XCTAssertEqual(span.text, "")
    }

    func testTSpanNodeWithText() {
        let span = SVGTSpanNode()
        span.text = "World"
        XCTAssertEqual(span.text, "World")
    }

    func testTSpanNodeWithStyle() {
        let span = SVGTSpanNode(style: SVGStyle(fill: "red"))
        span.text = "R"
        XCTAssertEqual(span.style.fill, "red")
        XCTAssertEqual(span.text, "R")
    }

    // MARK: - [B] Boundary Conditions

    func testTextBlockIsGroup() {
        let block = SVGTextBlock()
        XCTAssertTrue(block.children.isEmpty)
        let span = SVGTSpanNode()
        let textPath = SVGTextPath()
        block.addChild(textPath)
        textPath.addChild(span)
        XCTAssertEqual(block.children.count, 1)
    }

    func testTextPathHostBlockIsWeak() {
        var block: SVGTextBlock? = SVGTextBlock()
        let textPath = SVGTextPath()
        textPath.hostTextBlock = block
        XCTAssertNotNil(textPath.hostTextBlock)
        block = nil
        XCTAssertNil(textPath.hostTextBlock)
    }

    // MARK: - [I] Inverse: Parent Relationships

    func testTSpanParentIsTextPath() {
        let textPath = SVGTextPath()
        let span = SVGTSpanNode()
        textPath.addChild(span)
        XCTAssertTrue(span.parent === textPath)
    }

    func testTextPathParentIsTextBlock() {
        let block = SVGTextBlock()
        let textPath = SVGTextPath()
        block.addChild(textPath)
        XCTAssertTrue(textPath.parent === block)
    }
}
