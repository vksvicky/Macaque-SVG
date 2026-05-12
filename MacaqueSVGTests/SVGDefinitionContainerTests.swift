import XCTest

@testable import MacaqueSVG

final class SVGDefinitionContainerTests: XCTestCase {

    // MARK: - [Right] Definition Container

    func testDefinitionContainerIsGroup() {
        let defs = SVGDefinitionContainer()
        XCTAssertTrue(defs is SVGGroup)
        XCTAssertTrue(defs.children.isEmpty)
    }

    func testDefinitionContainerAcceptsChildren() {
        let defs = SVGDefinitionContainer()
        let path = SVGPath(d: "M0 0 L10 10", svgId: "defPath")
        defs.addChild(path)
        XCTAssertEqual(defs.children.count, 1)
        XCTAssertTrue(path.parent === defs)
    }

    func testDefinitionContainerChildrenIndexedInDocument() {
        let root = SVGRoot()
        let defs = SVGDefinitionContainer()
        let gradient = SVGLinearGradientDef(svgId: "g1")
        defs.addChild(gradient)
        root.addChild(defs)

        let doc = SVGDocument(root: root)
        XCTAssertNotNil(doc.idIndex["g1"])
        XCTAssertTrue(doc.idIndex["g1"] is SVGLinearGradientDef)
    }

    // MARK: - [Right] SVGMask

    func testMaskIsGroup() {
        let mask = SVGMask()
        XCTAssertTrue(mask is SVGGroup)
        XCTAssertTrue(mask.children.isEmpty)
    }

    func testMaskAcceptsGeometryChildren() {
        let mask = SVGMask()
        mask.addChild(SVGRect(width: 10, height: 10))
        mask.addChild(SVGCircle(cx: 5, cy: 5, r: 3))
        XCTAssertEqual(mask.children.count, 2)
    }

    // MARK: - [B] Boundary Conditions

    func testEmptyDefinitionContainerInDocumentIndex() {
        let root = SVGRoot()
        root.addChild(SVGDefinitionContainer())
        let doc = SVGDocument(root: root)
        XCTAssertTrue(doc.idIndex.isEmpty)
    }

    // MARK: - [Right] SVGNestedSVG

    func testNestedSVGIsGroup() {
        let nested = SVGNestedSVG()
        XCTAssertTrue(nested is SVGGroup)
        XCTAssertNil(nested.viewBox)
        XCTAssertNil(nested.width)
        XCTAssertNil(nested.height)
    }

    func testNestedSVGWithViewBox() {
        let nested = SVGNestedSVG()
        nested.viewBox = CGRect(x: 0, y: 0, width: 100, height: 100)
        nested.width = 200
        nested.height = 200
        XCTAssertEqual(nested.viewBox, CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertEqual(nested.width, 200)
    }
}
