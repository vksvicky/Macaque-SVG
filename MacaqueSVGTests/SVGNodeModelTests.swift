import XCTest
@testable import MacaqueSVG

final class SVGNodeModelTests: XCTestCase {

    // MARK: - [Right] SVGElement

    func testSVGElementHasUniqueNodeID() {
        let a = SVGElement()
        let b = SVGElement()
        XCTAssertNotEqual(a.nodeID, b.nodeID)
    }

    func testSVGElementIdentifiableIdMatchesNodeID() {
        let element = SVGElement()
        XCTAssertEqual(element.id, element.nodeID)
    }

    func testSVGElementDefaultValues() {
        let element = SVGElement()
        XCTAssertNil(element.svgId)
        XCTAssertNil(element.svgClass)
        XCTAssertEqual(element.transform, .identity)
        XCTAssertNil(element.parent)
    }

    // MARK: - [Right] SVGGroup.addChild

    func testAddChildSetsParentReference() {
        let group = SVGGroup()
        let child = SVGElement(svgId: "child1")
        group.addChild(child)

        XCTAssertTrue(child.parent === group)
        XCTAssertEqual(group.children.count, 1)
    }

    func testAddMultipleChildren() {
        let group = SVGGroup()
        let a = SVGElement()
        let b = SVGElement()
        group.addChild(a)
        group.addChild(b)

        XCTAssertEqual(group.children.count, 2)
        XCTAssertTrue(a.parent === group)
        XCTAssertTrue(b.parent === group)
    }

    // MARK: - [Right] SVGDocument.buildIdIndex

    func testBuildIdIndexFindsNestedElements() {
        let root = SVGRoot()
        let group = SVGGroup(svgId: "g1")
        let path = SVGPath(d: "M0,0", svgId: "p1")
        group.addChild(path)
        root.addChild(group)

        let doc = SVGDocument(root: root)

        XCTAssertTrue(doc.idIndex["g1"] === group)
        XCTAssertTrue(doc.idIndex["p1"] === path)
    }

    func testBuildIdIndexSkipsElementsWithoutId() {
        let root = SVGRoot()
        let noId = SVGElement()
        root.addChild(noId)

        let doc = SVGDocument(root: root)

        XCTAssertTrue(doc.idIndex.isEmpty)
    }

    func testBuildIdIndexSkipsEmptyStringId() {
        let root = SVGRoot()
        let empty = SVGElement(svgId: "")
        root.addChild(empty)

        let doc = SVGDocument(root: root)

        XCTAssertTrue(doc.idIndex.isEmpty)
    }

    // MARK: - [Right] SVGRoot.userSpaceViewport

    func testUserSpaceViewportWithViewBox() {
        let root = SVGRoot()
        root.viewBox = CGRect(x: 0, y: 0, width: 200, height: 100)
        root.width = 500
        root.height = 500

        let viewport = root.userSpaceViewport()
        XCTAssertEqual(viewport, CGRect(x: 0, y: 0, width: 200, height: 100), "viewBox takes priority")
    }

    func testUserSpaceViewportWithWidthHeight() {
        let root = SVGRoot()
        root.width = 400
        root.height = 300

        let viewport = root.userSpaceViewport()
        XCTAssertEqual(viewport, CGRect(x: 0, y: 0, width: 400, height: 300))
    }

    func testUserSpaceViewportDefaults() {
        let root = SVGRoot()

        let viewport = root.userSpaceViewport()
        XCTAssertEqual(viewport, CGRect(x: 0, y: 0, width: 320, height: 320))
    }

    func testUserSpaceViewportCustomDefault() {
        let root = SVGRoot()

        let viewport = root.userSpaceViewport(defaultSize: CGSize(width: 100, height: 50))
        XCTAssertEqual(viewport, CGRect(x: 0, y: 0, width: 100, height: 50))
    }

    func testUserSpaceViewportPartialWidthOnly() {
        let root = SVGRoot()
        root.width = 800

        let viewport = root.userSpaceViewport()
        XCTAssertEqual(viewport, CGRect(x: 0, y: 0, width: 800, height: 320))
    }

    // MARK: - [B] Boundary Conditions

    func testEmptyGroupHasNoChildren() {
        let group = SVGGroup()
        XCTAssertTrue(group.children.isEmpty)
    }

    func testDocumentWithNoIdsProducesEmptyIndex() {
        let root = SVGRoot()
        let doc = SVGDocument(root: root)
        XCTAssertTrue(doc.idIndex.isEmpty)
    }

    // MARK: - [I] Inverse - Parent reference is weak

    func testParentReferenceIsWeak() {
        let child = SVGElement()
        autoreleasepool {
            let group = SVGGroup()
            group.addChild(child)
            XCTAssertNotNil(child.parent)
        }
        XCTAssertNil(child.parent, "Weak parent should be nil after group is deallocated")
    }

    // MARK: - [Right] SVGStyle defaults

    func testSVGStyleDefaultValues() {
        let style = SVGStyle()
        XCTAssertNil(style.fill)
        XCTAssertNil(style.stroke)
        XCTAssertNil(style.strokeWidth)
        XCTAssertNil(style.opacity)
    }

    func testSVGStyleEquality() {
        var a = SVGStyle()
        var b = SVGStyle()
        XCTAssertEqual(a, b)

        a.fill = "red"
        b.fill = "red"
        XCTAssertEqual(a, b)

        b.fill = "blue"
        XCTAssertNotEqual(a, b)
    }
}
