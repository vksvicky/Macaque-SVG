import XCTest

@testable import MacaqueSVG

final class SVGParserTests: XCTestCase {
    private let parser = SVGParser()

    func testNestedSVGParsesWithoutDuplicateRootError() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <svg x="10" y="10" width="80" height="80" viewBox="0 0 50 50">
            <rect width="50" height="50" fill="red" />
          </svg>
        </svg>
        """#

        let document = try parser.parse(string: svg)
        let nested = try XCTUnwrap(document.root.children.first as? SVGNestedSVG)
        XCTAssertEqual(nested.viewBox, CGRect(x: 0, y: 0, width: 50, height: 50))
        XCTAssertEqual(nested.children.count, 1)
        XCTAssertTrue(nested.children.first is SVGRect)
    }

    func testParseMinimalSVGProducesRoot() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg"></svg>
        """#

        let document = try parser.parse(string: svg)
        XCTAssertNotNil(document.root)
        XCTAssertEqual(document.root.children.count, 0)
    }

    func testParseRectGeometryAndStyle() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <rect id="r1" x="10" y="20px" width="30" height="40"
            fill="red" stroke="#00f" stroke-width="2" opacity="0.5" />
        </svg>
        """#

        let document = try parser.parse(string: svg)
        let rect = try XCTUnwrap(document.root.children.first as? SVGRect)
        XCTAssertEqual(rect.svgId, "r1")
        XCTAssertEqual(rect.x, 10)
        XCTAssertEqual(rect.y, 20)
        XCTAssertEqual(rect.width, 30)
        XCTAssertEqual(rect.height, 40)
        XCTAssertEqual(rect.style.fill, "red")
        XCTAssertEqual(rect.style.stroke, "#00f")
        XCTAssertEqual(rect.style.strokeWidth, 2)
        XCTAssertEqual(rect.style.opacity, 0.5)
        XCTAssertEqual(document.root.viewBox, CGRect(x: 0, y: 0, width: 100, height: 100))
    }

    func testLinearGradientInDefsAndRectFillURL() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">
          <defs>
            <linearGradient id="g" x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%" stop-color="#ff0000" />
              <stop offset="100%" stop-color="#0000ff" />
            </linearGradient>
          </defs>
          <rect width="10" height="10" fill="url(#g)" />
        </svg>
        """#

        let document = try parser.parse(string: svg)
        let gradient = try XCTUnwrap(document.idIndex["g"] as? SVGLinearGradientDef)
        XCTAssertEqual(gradient.stops.count, 2)
        let rect = try XCTUnwrap(document.root.children.compactMap { $0 as? SVGRect }.first)
        XCTAssertEqual(rect.style.fill, "url(#g)")
    }

    func testParseImageElementWithDataURI() throws {
        let png1x1 =
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">
          <image x="1" y="2" width="3" height="4" href="data:image/png;base64,\(png1x1)" />
        </svg>
        """

        let document = try parser.parse(string: svg)
        let image = try XCTUnwrap(document.root.children.first as? SVGImage)
        XCTAssertEqual(image.x, 1)
        XCTAssertEqual(image.y, 2)
        XCTAssertEqual(image.width, 3)
        XCTAssertEqual(image.height, 4)
        XCTAssertTrue(image.href.contains("base64"))
        XCTAssertNotNil(image.decodedDataURIImage())
    }

    func testParsePolygonPoints() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg">
          <polygon points="0,0 10,0 5,10" fill="orange" />
        </svg>
        """#

        let document = try parser.parse(string: svg)
        let polygon = try XCTUnwrap(document.root.children.first as? SVGPolygon)
        XCTAssertEqual(polygon.points.count, 3)
        XCTAssertEqual(polygon.style.fill, "orange")
    }

    func testParseCircleAndPath() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg">
          <circle cx="5" cy="6" r="7" />
          <path d="M0 0 L10 10Z" id="p" />
        </svg>
        """#

        let document = try parser.parse(string: svg)
        XCTAssertEqual(document.root.children.count, 2)

        let circle = try XCTUnwrap(document.root.children.first as? SVGCircle)
        XCTAssertEqual(circle.cx, 5)
        XCTAssertEqual(circle.cy, 6)
        XCTAssertEqual(circle.r, 7)

        let path = try XCTUnwrap(document.root.children.last as? SVGPath)
        XCTAssertEqual(path.d, "M0 0 L10 10Z")
        XCTAssertEqual(path.svgId, "p")
    }

    func testNestedGroupsPreserveHierarchy() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg">
          <g id="outer">
            <rect x="0" y="0" width="1" height="1" />
            <g id="inner">
              <rect x="2" y="3" width="4" height="5" />
            </g>
          </g>
        </svg>
        """#

        let document = try parser.parse(string: svg)
        let outer = try XCTUnwrap(document.root.children.first as? SVGGroup)
        XCTAssertEqual(outer.svgId, "outer")
        XCTAssertEqual(outer.children.count, 2)

        let inner = try XCTUnwrap(outer.children.last as? SVGGroup)
        XCTAssertEqual(inner.svgId, "inner")
        let innerRect = try XCTUnwrap(inner.children.first as? SVGRect)
        XCTAssertEqual(innerRect.x, 2)
        XCTAssertEqual(innerRect.parent?.svgId, "inner")
    }

    func testTextCapturesCharacters() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg">
          <text x="1" y="2">Hello</text>
        </svg>
        """#

        let document = try parser.parse(string: svg)
        let text = try XCTUnwrap(document.root.children.first as? SVGTextBlock)
        XCTAssertEqual(text.x, 1)
        XCTAssertEqual(text.y, 2)
        XCTAssertEqual(text.plainText, "Hello")
    }

    func testMaskInDefsAndGroupMaskAttribute() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <defs>
            <mask id="m1">
              <polygon points="0,0 100,0 50,100" fill="white" />
            </mask>
          </defs>
          <g mask="url(#m1)">
            <rect width="100" height="100" fill="red" />
          </g>
        </svg>
        """#

        let document = try parser.parse(string: svg)
        let mask = try XCTUnwrap(document.idIndex["m1"] as? SVGMask)
        XCTAssertEqual(mask.children.count, 1)
        XCTAssertTrue(mask.children.first is SVGPolygon)

        let group = try XCTUnwrap(document.root.children.compactMap { $0 as? SVGGroup }.first { $0.maskHrefFragment != nil })
        XCTAssertEqual(group.maskHrefFragment, "m1")
    }

    func testTextPathWithTspans() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 20">
          <defs>
            <path id="p" d="M 0 10 H 100" />
          </defs>
          <text font-size="10">
            <textPath href="#p" startOffset="50%" text-anchor="middle">
              <tspan fill="#ff0000">A</tspan><tspan fill="#0000ff">B</tspan>
            </textPath>
          </text>
        </svg>
        """#

        let document = try parser.parse(string: svg)
        let textBlock = try XCTUnwrap(document.root.children.compactMap { $0 as? SVGTextBlock }.first)
        let textPath = try XCTUnwrap(textBlock.children.first as? SVGTextPath)
        XCTAssertEqual(textPath.pathHrefFragment, "p")
        XCTAssertEqual(textPath.startOffset, "50%")
        XCTAssertEqual(textPath.textAnchor, "middle")
        let spans = textPath.children.compactMap { $0 as? SVGTSpanNode }
        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(spans[0].text, "A")
        XCTAssertEqual(spans[0].style.fill, "#ff0000")
        XCTAssertEqual(spans[1].text, "B")
        XCTAssertEqual(spans[1].style.fill, "#0000ff")
    }

    func testTextPathInlineTextWithoutTspan() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 20">
          <defs>
            <path id="arc" d="M 0 10 H 100" />
          </defs>
          <text font-size="10" fill="#ffffff">
            <textPath href="#arc" startOffset="50%" text-anchor="middle">POLYCODE</textPath>
          </text>
        </svg>
        """#

        let document = try parser.parse(string: svg)
        let textBlock = try XCTUnwrap(document.root.children.compactMap { $0 as? SVGTextBlock }.first)
        let textPath = try XCTUnwrap(textBlock.children.first as? SVGTextPath)
        XCTAssertEqual(textPath.inlineText, "POLYCODE")
        XCTAssertTrue(textPath.children.compactMap { $0 as? SVGTSpanNode }.isEmpty)
    }

    func testTransformTranslateConcatenation() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg">
          <rect transform="translate(10 20) translate(3)" x="0" y="0" width="1" height="1" />
        </svg>
        """#

        let document = try parser.parse(string: svg)
        let rect = try XCTUnwrap(document.root.children.first as? SVGRect)
        XCTAssertEqual(rect.transform.tx, 13)
        XCTAssertEqual(rect.transform.ty, 20)
    }

    func testRectInlineStyle() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg">
          <rect x="0" y="0" width="1" height="1" style="fill: #f0f0f0; stroke: #333; stroke-width: 3px;" />
        </svg>
        """#

        let document = try parser.parse(string: svg)
        let rect = try XCTUnwrap(document.root.children.first as? SVGRect)
        XCTAssertEqual(rect.style.fill, "#f0f0f0")
        XCTAssertEqual(rect.style.stroke, "#333")
        XCTAssertEqual(rect.style.strokeWidth, 3)
    }

    func testStyleAttributeOverridesPresentationAttributes() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg">
          <rect fill="red" style="fill: blue;" x="0" y="0" width="1" height="1" />
        </svg>
        """#

        let document = try parser.parse(string: svg)
        let rect = try XCTUnwrap(document.root.children.first as? SVGRect)
        XCTAssertEqual(rect.style.fill, "blue")
    }

    func testStyleBlockAppliesClassFill() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg">
          <style>.shape { fill: #00ff00; }</style>
          <path class="shape" d="M0 0 L10 0 L10 10 Z" />
        </svg>
        """#

        let document = try parser.parse(string: svg)
        let path = try XCTUnwrap(document.root.children.first as? SVGPath)
        XCTAssertEqual(path.style.fill, "#00ff00")
    }

    func testOnlyDefsStoresPathWithId() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">
          <defs>
            <path id="a" d="M0 0 H10 V10 H0 Z" fill="blue" />
          </defs>
        </svg>
        """#

        let document = try parser.parse(string: svg)
        XCTAssertTrue(document.root.children.first is SVGDefinitionContainer)
        XCTAssertNotNil(document.idIndex["a"])
    }

    func testUseResolvesHrefInIdIndex() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">
          <defs>
            <path id="p" d="M0 0 L10 0 L10 10 Z" fill="red" />
          </defs>
          <use href="#p" x="0" y="0" />
        </svg>
        """#

        let document = try parser.parse(string: svg)
        XCTAssertNotNil(document.idIndex["p"])
        let use = try XCTUnwrap(document.root.children.first(where: { $0 is SVGUse }) as? SVGUse)
        XCTAssertEqual(use.hrefFragment, "p")
    }

    func testEmptyDataThrows() {
        XCTAssertThrowsError(try parser.parse(data: Data())) { error in
            XCTAssertEqual(error as? SVGParserError, .emptyData)
        }
    }

    func testInvalidXMLDoesNotProduceDocument() {
        let bad = "<svg><unclosed>"
        XCTAssertThrowsError(try parser.parse(string: bad))
    }
}
