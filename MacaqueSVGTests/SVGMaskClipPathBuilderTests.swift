import CoreGraphics
import XCTest

@testable import MacaqueSVG

final class SVGMaskClipPathBuilderTests: XCTestCase {

    // MARK: - [Right] Are the Results Right?

    func testPolygonChildProducesPath() {
        let mask = SVGMask()
        let polygon = SVGPolygon(points: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 10, y: 0),
            CGPoint(x: 5, y: 10),
        ])
        mask.addChild(polygon)

        let path = SVGMaskClipPathBuilder.combinedPath(from: mask)
        XCTAssertNotNil(path)
        let bounds = path!.boundingRect
        XCTAssertEqual(bounds.width, 10, accuracy: 0.01)
        XCTAssertEqual(bounds.height, 10, accuracy: 0.01)
    }

    func testRectChildProducesPath() {
        let mask = SVGMask()
        let rect = SVGRect(x: 5, y: 5, width: 20, height: 30)
        mask.addChild(rect)

        let path = SVGMaskClipPathBuilder.combinedPath(from: mask)
        XCTAssertNotNil(path)
        let bounds = path!.boundingRect
        XCTAssertEqual(bounds.origin.x, 5, accuracy: 0.01)
        XCTAssertEqual(bounds.origin.y, 5, accuracy: 0.01)
        XCTAssertEqual(bounds.width, 20, accuracy: 0.01)
        XCTAssertEqual(bounds.height, 30, accuracy: 0.01)
    }

    func testCircleChildProducesEllipsePath() {
        let mask = SVGMask()
        let circle = SVGCircle(cx: 10, cy: 10, r: 5)
        mask.addChild(circle)

        let path = SVGMaskClipPathBuilder.combinedPath(from: mask)
        XCTAssertNotNil(path)
        let bounds = path!.boundingRect
        XCTAssertEqual(bounds.origin.x, 5, accuracy: 0.5)
        XCTAssertEqual(bounds.origin.y, 5, accuracy: 0.5)
        XCTAssertEqual(bounds.width, 10, accuracy: 0.5)
        XCTAssertEqual(bounds.height, 10, accuracy: 0.5)
    }

    func testPathChildProducesCombinedPath() {
        let mask = SVGMask()
        let svgPath = SVGPath(d: "M0 0 L10 0 L10 10 L0 10 Z")
        mask.addChild(svgPath)

        let path = SVGMaskClipPathBuilder.combinedPath(from: mask)
        XCTAssertNotNil(path)
        let bounds = path!.boundingRect
        XCTAssertEqual(bounds.width, 10, accuracy: 0.01)
        XCTAssertEqual(bounds.height, 10, accuracy: 0.01)
    }

    func testMultipleChildrenCombined() {
        let mask = SVGMask()
        mask.addChild(SVGRect(x: 0, y: 0, width: 10, height: 10))
        mask.addChild(SVGRect(x: 20, y: 20, width: 10, height: 10))

        let path = SVGMaskClipPathBuilder.combinedPath(from: mask)
        XCTAssertNotNil(path)
        let bounds = path!.boundingRect
        XCTAssertEqual(bounds.width, 30, accuracy: 0.01)
        XCTAssertEqual(bounds.height, 30, accuracy: 0.01)
    }

    func testRoundedRectWithCornerRadius() {
        let mask = SVGMask()
        let rect = SVGRect(x: 0, y: 0, width: 50, height: 50, rx: 5, ry: 5)
        mask.addChild(rect)

        let path = SVGMaskClipPathBuilder.combinedPath(from: mask)
        XCTAssertNotNil(path)
    }

    // MARK: - [B] Boundary Conditions

    func testEmptyMaskReturnsNil() {
        let mask = SVGMask()
        XCTAssertNil(SVGMaskClipPathBuilder.combinedPath(from: mask))
    }

    func testZeroSizeRectReturnsNil() {
        let mask = SVGMask()
        mask.addChild(SVGRect(x: 0, y: 0, width: 0, height: 0))
        XCTAssertNil(SVGMaskClipPathBuilder.combinedPath(from: mask))
    }

    func testZeroRadiusCircleReturnsNil() {
        let mask = SVGMask()
        mask.addChild(SVGCircle(cx: 0, cy: 0, r: 0))
        XCTAssertNil(SVGMaskClipPathBuilder.combinedPath(from: mask))
    }

    func testPolylineWithNoPointsReturnsNil() {
        let mask = SVGMask()
        mask.addChild(SVGPolygon(points: []))
        XCTAssertNil(SVGMaskClipPathBuilder.combinedPath(from: mask))
    }

    // MARK: - [E] Error Conditions

    func testNonGeometryChildrenIgnored() {
        let mask = SVGMask()
        let textBlock = SVGTextBlock()
        mask.addChild(textBlock)
        XCTAssertNil(SVGMaskClipPathBuilder.combinedPath(from: mask))
    }

    // MARK: - [I] Inverse Relationships

    func testPolygonPathContainsInnerPoint() {
        let mask = SVGMask()
        mask.addChild(SVGPolygon(points: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 0, y: 100),
        ]))

        let path = SVGMaskClipPathBuilder.combinedPath(from: mask)!
        XCTAssertTrue(path.contains(CGPoint(x: 50, y: 50)))
        XCTAssertFalse(path.contains(CGPoint(x: 200, y: 200)))
    }
}
