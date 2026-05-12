import CoreGraphics
import XCTest

@testable import MacaqueSVG

final class SVGHitTesterTests: XCTestCase {

    // MARK: - Helpers

    private func makeDocument(with children: [SVGElement]) -> (SVGRoot, [String: SVGElement]) {
        let root = SVGRoot()
        for child in children {
            root.addChild(child)
        }
        let doc = SVGDocument(root: root)
        return (root, doc.idIndex)
    }

    // MARK: - [Right] Basic hit testing

    func testHitTestRect() {
        let rect = SVGRect(x: 10, y: 10, width: 50, height: 50, svgId: "r1")
        let (root, idIndex) = makeDocument(with: [rect])

        let hit = SVGHitTester.hitTest(point: CGPoint(x: 35, y: 35), root: root, idIndex: idIndex)
        XCTAssertTrue(hit === rect)
    }

    func testMissRect() {
        let rect = SVGRect(x: 10, y: 10, width: 50, height: 50)
        let (root, idIndex) = makeDocument(with: [rect])

        let hit = SVGHitTester.hitTest(point: CGPoint(x: 5, y: 5), root: root, idIndex: idIndex)
        XCTAssertNil(hit)
    }

    func testHitTestCircle() {
        let circle = SVGCircle(cx: 50, cy: 50, r: 20, svgId: "c1")
        let (root, idIndex) = makeDocument(with: [circle])

        let hit = SVGHitTester.hitTest(point: CGPoint(x: 50, y: 50), root: root, idIndex: idIndex)
        XCTAssertTrue(hit === circle)
    }

    func testMissCircle() {
        let circle = SVGCircle(cx: 50, cy: 50, r: 20)
        let (root, idIndex) = makeDocument(with: [circle])

        let hit = SVGHitTester.hitTest(point: CGPoint(x: 100, y: 100), root: root, idIndex: idIndex)
        XCTAssertNil(hit)
    }

    func testHitTestPath() {
        let path = SVGPath(d: "M0 0 L100 0 L100 100 L0 100 Z", svgId: "p1")
        let (root, idIndex) = makeDocument(with: [path])

        let hit = SVGHitTester.hitTest(point: CGPoint(x: 50, y: 50), root: root, idIndex: idIndex)
        XCTAssertTrue(hit === path)
    }

    func testHitTestPolygon() {
        let polygon = SVGPolygon(points: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 0, y: 100),
        ], svgId: "poly1")
        let (root, idIndex) = makeDocument(with: [polygon])

        let hit = SVGHitTester.hitTest(point: CGPoint(x: 50, y: 50), root: root, idIndex: idIndex)
        XCTAssertTrue(hit === polygon)
    }

    // MARK: - [Right] Topmost element wins (reverse order)

    func testTopmostElementIsHit() {
        let bottom = SVGRect(x: 0, y: 0, width: 100, height: 100, svgId: "bottom")
        let top = SVGRect(x: 0, y: 0, width: 100, height: 100, svgId: "top")
        let (root, idIndex) = makeDocument(with: [bottom, top])

        let hit = SVGHitTester.hitTest(point: CGPoint(x: 50, y: 50), root: root, idIndex: idIndex)
        XCTAssertTrue(hit === top)
    }

    // MARK: - [Right] Group traversal

    func testHitTestInsideGroup() {
        let rect = SVGRect(x: 10, y: 10, width: 30, height: 30, svgId: "nested")
        let group = SVGGroup()
        group.addChild(rect)
        let (root, idIndex) = makeDocument(with: [group])

        let hit = SVGHitTester.hitTest(point: CGPoint(x: 25, y: 25), root: root, idIndex: idIndex)
        XCTAssertTrue(hit === rect)
    }

    func testDeepNestedGroupHit() {
        let rect = SVGRect(x: 0, y: 0, width: 50, height: 50, svgId: "deep")
        let inner = SVGGroup()
        inner.addChild(rect)
        let outer = SVGGroup()
        outer.addChild(inner)
        let (root, idIndex) = makeDocument(with: [outer])

        let hit = SVGHitTester.hitTest(point: CGPoint(x: 25, y: 25), root: root, idIndex: idIndex)
        XCTAssertTrue(hit === rect)
    }

    // MARK: - [Right] Skips defs and masks

    func testDefinitionContainerSkipped() {
        let defs = SVGDefinitionContainer()
        let path = SVGPath(d: "M0 0 L100 0 L100 100 Z", svgId: "hidden")
        defs.addChild(path)
        let (root, idIndex) = makeDocument(with: [defs])

        let hit = SVGHitTester.hitTest(point: CGPoint(x: 50, y: 25), root: root, idIndex: idIndex)
        XCTAssertNil(hit)
    }

    func testMaskSkipped() {
        let mask = SVGMask()
        mask.addChild(SVGRect(x: 0, y: 0, width: 100, height: 100))
        let (root, idIndex) = makeDocument(with: [mask])

        let hit = SVGHitTester.hitTest(point: CGPoint(x: 50, y: 50), root: root, idIndex: idIndex)
        XCTAssertNil(hit)
    }

    // MARK: - [B] Boundary Conditions

    func testEmptyRootReturnsNil() {
        let (root, idIndex) = makeDocument(with: [])
        let hit = SVGHitTester.hitTest(point: CGPoint(x: 50, y: 50), root: root, idIndex: idIndex)
        XCTAssertNil(hit)
    }

    func testHitAtRectEdge() {
        let rect = SVGRect(x: 0, y: 0, width: 100, height: 100)
        let (root, idIndex) = makeDocument(with: [rect])

        let hitOrigin = SVGHitTester.hitTest(point: CGPoint(x: 0, y: 0), root: root, idIndex: idIndex)
        XCTAssertTrue(hitOrigin === rect)

        let hitCorner = SVGHitTester.hitTest(point: CGPoint(x: 100, y: 100), root: root, idIndex: idIndex)
        XCTAssertNil(hitCorner, "CGRect.contains excludes maxX/maxY")
    }

    func testHitAtCircleEdge() {
        let circle = SVGCircle(cx: 50, cy: 50, r: 10)
        let (root, idIndex) = makeDocument(with: [circle])

        let hitOnEdge = SVGHitTester.hitTest(
            point: CGPoint(x: 60, y: 50), root: root, idIndex: idIndex
        )
        XCTAssertTrue(hitOnEdge === circle, "Point exactly on radius should hit")
    }

    func testPolygonWithLessThan3PointsMisses() {
        let polygon = SVGPolygon(points: [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10)])
        let (root, idIndex) = makeDocument(with: [polygon])

        let hit = SVGHitTester.hitTest(point: CGPoint(x: 5, y: 5), root: root, idIndex: idIndex)
        XCTAssertNil(hit)
    }

    // MARK: - [Right] Transforms

    func testHitTestWithTranslateTransform() {
        let rect = SVGRect(x: 0, y: 0, width: 50, height: 50, svgId: "translated")
        rect.transform = CGAffineTransform(translationX: 100, y: 100)
        let (root, idIndex) = makeDocument(with: [rect])

        let hitOldPos = SVGHitTester.hitTest(
            point: CGPoint(x: 25, y: 25), root: root, idIndex: idIndex
        )
        XCTAssertNil(hitOldPos, "Original position should not hit after translate")

        let hitNewPos = SVGHitTester.hitTest(
            point: CGPoint(x: 125, y: 125), root: root, idIndex: idIndex
        )
        XCTAssertTrue(hitNewPos === rect)
    }

    func testHitTestWithScaleTransform() {
        let rect = SVGRect(x: 0, y: 0, width: 10, height: 10, svgId: "scaled")
        rect.transform = CGAffineTransform(scaleX: 5, y: 5)
        let (root, idIndex) = makeDocument(with: [rect])

        let hit = SVGHitTester.hitTest(
            point: CGPoint(x: 25, y: 25), root: root, idIndex: idIndex
        )
        XCTAssertTrue(hit === rect)
    }

    // MARK: - [E] Error Conditions

    func testUnrecognizedElementTypeMisses() {
        let textBlock = SVGTextBlock()
        textBlock.x = 0
        textBlock.y = 0
        let (root, idIndex) = makeDocument(with: [textBlock])

        let hit = SVGHitTester.hitTest(point: CGPoint(x: 0, y: 0), root: root, idIndex: idIndex)
        XCTAssertNil(hit)
    }

    func testEmptyPathMisses() {
        let path = SVGPath(d: "")
        let (root, idIndex) = makeDocument(with: [path])

        let hit = SVGHitTester.hitTest(point: CGPoint(x: 0, y: 0), root: root, idIndex: idIndex)
        XCTAssertNil(hit)
    }

    // MARK: - [C] Cross-Check with containment

    func testCircleHitMatchesDistanceFormula() {
        let cx: CGFloat = 30
        let cy: CGFloat = 40
        let r: CGFloat = 15
        let circle = SVGCircle(cx: cx, cy: cy, r: r)
        let (root, idIndex) = makeDocument(with: [circle])

        let inside = CGPoint(x: cx + 5, y: cy + 5)
        let dist = hypot(inside.x - cx, inside.y - cy)
        XCTAssertTrue(dist <= r)
        XCTAssertNotNil(SVGHitTester.hitTest(point: inside, root: root, idIndex: idIndex))

        let outside = CGPoint(x: cx + r + 1, y: cy)
        let dist2 = hypot(outside.x - cx, outside.y - cy)
        XCTAssertTrue(dist2 > r)
        XCTAssertNil(SVGHitTester.hitTest(point: outside, root: root, idIndex: idIndex))
    }

    // MARK: - [P] Performance

    func testHitTestPerformanceWithManyElements() {
        let root = SVGRoot()
        for i in 0..<200 {
            let x = CGFloat(i % 20) * 50
            let y = CGFloat(i / 20) * 50
            root.addChild(SVGRect(x: x, y: y, width: 40, height: 40))
        }
        let doc = SVGDocument(root: root)

        measure {
            for _ in 0..<1000 {
                _ = SVGHitTester.hitTest(
                    point: CGPoint(x: 525, y: 225), root: root, idIndex: doc.idIndex
                )
            }
        }
    }
}
