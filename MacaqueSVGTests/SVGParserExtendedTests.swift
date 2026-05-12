import XCTest

@testable import MacaqueSVG

final class SVGParserExtendedTests: XCTestCase {
    private let parser = SVGParser()

    // MARK: - [Right] Ellipse (not yet supported — silently ignored)

    func testEllipseElementIsSilentlyIgnored() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg">
          <ellipse cx="50" cy="50" rx="40" ry="20"/>
        </svg>
        """#
        let document = try parser.parse(string: svg)
        XCTAssertNotNil(document.root)
        XCTAssertEqual(document.root.children.count, 0, "Unsupported <ellipse> should be silently skipped")
    }

    // MARK: - [Right] Line (not yet supported — silently ignored)

    func testLineElementIsSilentlyIgnored() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg">
          <line x1="0" y1="0" x2="100" y2="100" stroke="black"/>
        </svg>
        """#
        let document = try parser.parse(string: svg)
        XCTAssertNotNil(document.root)
        XCTAssertEqual(document.root.children.count, 0, "Unsupported <line> should be silently skipped")
    }

    // MARK: - [Right] Polyline

    func testParsePolylineElement() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg">
          <polyline points="0,0 10,0 10,10 0,10" fill="none" stroke="red"/>
        </svg>
        """#
        let document = try parser.parse(string: svg)
        let polyline = try XCTUnwrap(document.root.children.first as? SVGPolyline)
        XCTAssertEqual(polyline.points.count, 4)
        XCTAssertEqual(polyline.points[0], CGPoint(x: 0, y: 0))
        XCTAssertEqual(polyline.points[1], CGPoint(x: 10, y: 0))
    }

    // MARK: - [Right] Radial gradient in defs

    func testParseRadialGradientInDefs() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg">
          <defs>
            <radialGradient id="rg" cx="0.5" cy="0.5" r="0.5">
              <stop offset="0%" stop-color="white"/>
              <stop offset="100%" stop-color="black"/>
            </radialGradient>
          </defs>
          <rect width="100" height="100" fill="url(#rg)"/>
        </svg>
        """#
        let document = try parser.parse(string: svg)
        let gradient = try XCTUnwrap(document.idIndex["rg"] as? SVGRadialGradientDef)
        XCTAssertEqual(gradient.stops.count, 2)
        XCTAssertEqual(gradient.cx, 0.5, accuracy: 0.001)
        XCTAssertEqual(gradient.cy, 0.5, accuracy: 0.001)
        XCTAssertEqual(gradient.r, 0.5, accuracy: 0.001)
    }

    // MARK: - [Right] Multiple style blocks

    func testParseMultipleStyleBlocks() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg">
          <style>.a { fill: red; }</style>
          <style>.b { fill: blue; }</style>
          <rect class="a" x="0" y="0" width="1" height="1"/>
          <rect class="b" x="1" y="0" width="1" height="1"/>
        </svg>
        """#
        let document = try parser.parse(string: svg)
        let rects = document.root.children.compactMap { $0 as? SVGRect }
        XCTAssertEqual(rects.count, 2)
        XCTAssertEqual(rects[0].style.fill, "red")
        XCTAssertEqual(rects[1].style.fill, "blue")
    }

    // MARK: - [Right] viewBox with comma separators

    func testViewBoxWithCommaSeparators() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0,0,200,100">
        </svg>
        """#
        let document = try parser.parse(string: svg)
        XCTAssertEqual(document.root.viewBox, CGRect(x: 0, y: 0, width: 200, height: 100))
    }

    // MARK: - [Right] preserveAspectRatio on image

    func testPreserveAspectRatioAttributeOnImage() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg">
          <image href="data:image/png;base64,AA==" width="10" height="10" preserveAspectRatio="xMinYMin meet"/>
        </svg>
        """#
        let document = try parser.parse(string: svg)
        let image = try XCTUnwrap(document.root.children.first as? SVGImage)
        XCTAssertEqual(image.preserveAspectRatio, "xMinYMin meet")
    }

    // MARK: - [Right] <use> with xlink:href

    func testUseWithXlinkHref() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
          <defs>
            <rect id="box" width="10" height="10"/>
          </defs>
          <use xlink:href="#box" x="5" y="5"/>
        </svg>
        """#
        let document = try parser.parse(string: svg)
        let use = try XCTUnwrap(document.root.children.compactMap({ $0 as? SVGUse }).first)
        XCTAssertEqual(use.hrefFragment, "box")
        XCTAssertEqual(use.x, 5)
        XCTAssertEqual(use.y, 5)
    }

    // MARK: - [B] SVG with only whitespace text nodes

    func testSVGWithOnlyWhitespaceTextNodes() throws {
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\">\n   \n   \n</svg>"
        let document = try parser.parse(string: svg)
        XCTAssertNotNil(document.root)
        XCTAssertEqual(document.root.children.count, 0)
    }

    // MARK: - [B] Deeply nested groups

    func testDeeplyNestedGroups() throws {
        var opening = ""
        var closing = ""
        for i in 0..<12 {
            opening += "<g id=\"g\(i)\">"
            closing = "</g>" + closing
        }
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\">\(opening)<rect width=\"1\" height=\"1\"/>\(closing)</svg>"
        let document = try parser.parse(string: svg)
        XCTAssertNotNil(document.root)

        var group: SVGGroup = document.root
        for i in 0..<12 {
            let child = try XCTUnwrap(group.children.first as? SVGGroup, "Expected nested group at level \(i)")
            XCTAssertEqual(child.svgId, "g\(i)")
            group = child
        }
        XCTAssertTrue(group.children.first is SVGRect)
    }

    // MARK: - [Right] Transforms: scale, matrix

    func testTransformScale() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg">
          <rect transform="scale(2, 3)" width="1" height="1"/>
        </svg>
        """#
        let document = try parser.parse(string: svg)
        let rect = try XCTUnwrap(document.root.children.first as? SVGRect)
        XCTAssertEqual(rect.transform.a, 2, accuracy: 0.001)
        XCTAssertEqual(rect.transform.d, 3, accuracy: 0.001)
    }

    func testTransformRotateIsIgnored() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg">
          <rect transform="rotate(45)" width="1" height="1"/>
        </svg>
        """#
        let document = try parser.parse(string: svg)
        let rect = try XCTUnwrap(document.root.children.first as? SVGRect)
        XCTAssertTrue(rect.transform.isIdentity, "rotate() is not yet supported and should be identity")
    }

    func testTransformMatrix() throws {
        let svg = #"""
        <svg xmlns="http://www.w3.org/2000/svg">
          <rect transform="matrix(1, 0, 0, 1, 10, 20)" width="1" height="1"/>
        </svg>
        """#
        let document = try parser.parse(string: svg)
        let rect = try XCTUnwrap(document.root.children.first as? SVGRect)
        XCTAssertEqual(rect.transform.tx, 10, accuracy: 0.001)
        XCTAssertEqual(rect.transform.ty, 20, accuracy: 0.001)
    }

    // MARK: - [E] Non-SVG root element

    func testNonSVGRootElementThrows() {
        let html = "<html><body>Not SVG</body></html>"
        XCTAssertThrowsError(try parser.parse(string: html)) { error in
            let svgError = error as? SVGParserError
            XCTAssertTrue(
                svgError == .noRootSVG || svgError == .invalidStructure,
                "Expected noRootSVG or invalidStructure, got \(error)"
            )
        }
    }

    // MARK: - [Right] svgSource preserved

    func testSvgSourceIsPreservedInParsedDocument() throws {
        let svg = #"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"></svg>"#
        let document = try parser.parse(string: svg)
        XCTAssertEqual(document.svgSource, svg)
    }
}
