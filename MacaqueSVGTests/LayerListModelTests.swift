import CoreGraphics
import XCTest

@testable import MacaqueSVG

final class LayerListModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeDocument(with children: [SVGElement]) -> (SVGRoot, [String: SVGElement]) {
        let root = SVGRoot()
        for child in children {
            root.addChild(child)
        }
        let doc = SVGDocument(root: root)
        return (root, doc.idIndex)
    }

    // MARK: - [Right] Results

    func testVisibilityDefaultsToTrue() {
        let element = SVGRect(x: 0, y: 0, width: 10, height: 10)
        XCTAssertTrue(element.isVisible)
    }

    func testToggleVisibility() {
        let element = SVGRect(x: 0, y: 0, width: 10, height: 10)

        element.isVisible = false
        XCTAssertFalse(element.isVisible)

        element.isVisible = true
        XCTAssertTrue(element.isVisible)
    }

    func testHitTesterSkipsInvisibleElements() {
        let rect = SVGRect(x: 0, y: 0, width: 100, height: 100, svgId: "r1")
        rect.isVisible = false
        let (root, idIndex) = makeDocument(with: [rect])

        let hit = SVGHitTester.hitTest(point: CGPoint(x: 50, y: 50), root: root, idIndex: idIndex)
        XCTAssertNil(hit)
    }

    func testHitTesterFindsVisibleElements() {
        let rect = SVGRect(x: 0, y: 0, width: 100, height: 100, svgId: "r1")
        rect.isVisible = true
        let (root, idIndex) = makeDocument(with: [rect])

        let hit = SVGHitTester.hitTest(point: CGPoint(x: 50, y: 50), root: root, idIndex: idIndex)
        XCTAssertTrue(hit === rect)
    }

    // MARK: - [B] Boundary Conditions

    func testInvisibleGroupHidesAllChildren() {
        let rect = SVGRect(x: 0, y: 0, width: 100, height: 100, svgId: "child")
        let group = SVGGroup()
        group.addChild(rect)
        group.isVisible = false
        let (root, idIndex) = makeDocument(with: [group])

        let hit = SVGHitTester.hitTest(point: CGPoint(x: 50, y: 50), root: root, idIndex: idIndex)
        XCTAssertNil(hit)
    }

    func testChildInvisibleButGroupVisible() {
        let rect = SVGRect(x: 0, y: 0, width: 100, height: 100, svgId: "child")
        rect.isVisible = false
        let group = SVGGroup()
        group.addChild(rect)
        group.isVisible = true
        let (root, idIndex) = makeDocument(with: [group])

        let hit = SVGHitTester.hitTest(point: CGPoint(x: 50, y: 50), root: root, idIndex: idIndex)
        XCTAssertNil(hit)
    }

    func testEmptyGroupVisibility() {
        let group = SVGGroup()
        XCTAssertTrue(group.isVisible)

        group.isVisible = false
        XCTAssertFalse(group.isVisible)
        XCTAssertTrue(group.children.isEmpty)

        group.isVisible = true
        XCTAssertTrue(group.isVisible)
    }

    // MARK: - [I/C] Inverse & Cross-Checking

    func testVisibilityDoesNotAffectOtherProperties() {
        let style = SVGStyle(fill: "red", stroke: "blue", strokeWidth: 2.0, opacity: 0.8)
        let transform = CGAffineTransform(translationX: 10, y: 20)
        let element = SVGRect(x: 5, y: 5, width: 50, height: 50, svgId: "test", transform: transform, style: style)

        element.isVisible = false

        XCTAssertEqual(element.transform, transform)
        XCTAssertEqual(element.style, style)
        XCTAssertEqual(element.svgId, "test")

        element.isVisible = true

        XCTAssertEqual(element.transform, transform)
        XCTAssertEqual(element.style, style)
        XCTAssertEqual(element.svgId, "test")
    }

    func testMultipleElementsVisibilityIndependent() {
        let rect1 = SVGRect(x: 0, y: 0, width: 50, height: 50, svgId: "r1")
        let rect2 = SVGRect(x: 60, y: 0, width: 50, height: 50, svgId: "r2")
        let (root, idIndex) = makeDocument(with: [rect1, rect2])

        rect1.isVisible = false

        XCTAssertTrue(rect2.isVisible)
        let hit = SVGHitTester.hitTest(point: CGPoint(x: 85, y: 25), root: root, idIndex: idIndex)
        XCTAssertTrue(hit === rect2)

        let missHit = SVGHitTester.hitTest(point: CGPoint(x: 25, y: 25), root: root, idIndex: idIndex)
        XCTAssertNil(missHit)
    }

    // MARK: - Tree Structure

    func testRootChildrenCount() {
        let rect = SVGRect(x: 0, y: 0, width: 10, height: 10)
        let circle = SVGCircle(cx: 50, cy: 50, r: 10)
        let group = SVGGroup()
        let (root, _) = makeDocument(with: [rect, circle, group])

        XCTAssertEqual(root.children.count, 3)
    }

    func testNestedGroupStructure() {
        let leaf = SVGRect(x: 0, y: 0, width: 10, height: 10)
        let inner = SVGGroup()
        inner.addChild(leaf)
        let outer = SVGGroup()
        outer.addChild(inner)
        let (root, _) = makeDocument(with: [outer])

        XCTAssertTrue(leaf.parent === inner)
        XCTAssertTrue(inner.parent === outer)
        XCTAssertTrue(outer.parent === root)
        XCTAssertEqual(root.children.count, 1)
        XCTAssertEqual(outer.children.count, 1)
        XCTAssertEqual(inner.children.count, 1)
    }

    func testDefinitionContainerInTree() {
        let defs = SVGDefinitionContainer()
        let rect = SVGRect(x: 0, y: 0, width: 100, height: 100, svgId: "inDefs")
        defs.addChild(rect)

        let visibleRect = SVGRect(x: 0, y: 0, width: 100, height: 100, svgId: "visible")
        let (root, idIndex) = makeDocument(with: [defs, visibleRect])

        XCTAssertEqual(root.children.count, 2)
        XCTAssertTrue(root.children[0] is SVGDefinitionContainer)

        let hit = SVGHitTester.hitTest(point: CGPoint(x: 50, y: 50), root: root, idIndex: idIndex)
        XCTAssertTrue(hit === visibleRect)
    }

    // MARK: - [E] Error Conditions

    func testHitTestWithEmptyRoot() {
        let (root, idIndex) = makeDocument(with: [])

        let hit = SVGHitTester.hitTest(point: CGPoint(x: 50, y: 50), root: root, idIndex: idIndex)
        XCTAssertNil(hit)
    }

    func testHitTestOutsideBounds() {
        let rect = SVGRect(x: 10, y: 10, width: 20, height: 20)
        let (root, idIndex) = makeDocument(with: [rect])

        let hit = SVGHitTester.hitTest(point: CGPoint(x: 500, y: 500), root: root, idIndex: idIndex)
        XCTAssertNil(hit)
    }
}
