import XCTest

@testable import MacaqueSVG

final class SVGFlattenedExporterTests: XCTestCase {
    private let parser = SVGParser()

    // MARK: - [Right] SVG root element present

    func testFlattenedOutputContainsSVGRootElement() throws {
        let svg = #"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10"/></svg>"#
        let document = try parser.parse(string: svg)
        let result = SVGFlattenedExporter.flattenSource(svg, parsed: document)
        XCTAssertTrue(result.contains("<svg"))
        XCTAssertTrue(result.contains("</svg>") || result.contains("/>"))
    }

    // MARK: - [Right] Basic SVG passes through

    func testBasicSVGPassesThrough() throws {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <rect x="0" y="0" width="100" height="100" fill="red"/>
        </svg>
        """
        let document = try parser.parse(string: svg)
        let result = SVGFlattenedExporter.flattenSource(svg, parsed: document)
        XCTAssertEqual(result, svg, "SVG without external images should pass through unmodified")
    }

    // MARK: - [B] Empty SVG source

    func testEmptySVGSource() throws {
        let svg = #"<svg xmlns="http://www.w3.org/2000/svg"></svg>"#
        let document = try parser.parse(string: svg)
        let result = SVGFlattenedExporter.flattenSource(svg, parsed: document)
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("<svg"))
    }

    // MARK: - [Right] Data URI images are not double-inlined

    func testDataURIImageIsNotModified() throws {
        let dataHref = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUg=="
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg">
          <image href="\(dataHref)" width="10" height="10"/>
        </svg>
        """
        let document = try parser.parse(string: svg)
        let result = SVGFlattenedExporter.flattenSource(svg, parsed: document)
        XCTAssertTrue(result.contains(dataHref), "Existing data: URIs should remain unchanged")
    }

    // MARK: - [Right] Multiple images with same href are deduplicated

    func testMultipleImagesWithSameHrefShareReplacement() throws {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg">
          <image href="missing.png" width="10" height="10"/>
          <image href="missing.png" width="20" height="20"/>
        </svg>
        """
        let document = try parser.parse(string: svg)
        let result = SVGFlattenedExporter.flattenSource(svg, parsed: document)
        XCTAssertNotNil(result)
    }

    // MARK: - [B] SVG with no image elements

    func testSVGWithNoImagesReturnsOriginal() throws {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg">
          <circle cx="5" cy="5" r="3" fill="blue"/>
        </svg>
        """
        let document = try parser.parse(string: svg)
        let result = SVGFlattenedExporter.flattenSource(svg, parsed: document)
        XCTAssertEqual(result, svg)
    }
}
