import CoreGraphics
import XCTest

@testable import MacaqueSVG

final class SVGCoordinateMapperTests: XCTestCase {

    // MARK: - [Right] Are the Results Right?

    func testIdentityMappingViewToDocument() {
        let viewSize = CGSize(width: 100, height: 100)
        let viewBox = CGRect(x: 0, y: 0, width: 100, height: 100)
        let point = CGPoint(x: 50, y: 50)

        let docPoint = SVGCoordinateMapper.viewToDocument(
            point: point, viewSize: viewSize, viewBox: viewBox
        )
        XCTAssertEqual(docPoint.x, 50, accuracy: 0.01)
        XCTAssertEqual(docPoint.y, 50, accuracy: 0.01)
    }

    func testIdentityMappingDocumentToView() {
        let viewSize = CGSize(width: 100, height: 100)
        let viewBox = CGRect(x: 0, y: 0, width: 100, height: 100)
        let point = CGPoint(x: 25, y: 75)

        let viewPoint = SVGCoordinateMapper.documentToView(
            point: point, viewSize: viewSize, viewBox: viewBox
        )
        XCTAssertEqual(viewPoint.x, 25, accuracy: 0.01)
        XCTAssertEqual(viewPoint.y, 75, accuracy: 0.01)
    }

    func testScaledUpMapping() {
        let viewSize = CGSize(width: 200, height: 200)
        let viewBox = CGRect(x: 0, y: 0, width: 100, height: 100)

        let docPoint = SVGCoordinateMapper.viewToDocument(
            point: CGPoint(x: 100, y: 100), viewSize: viewSize, viewBox: viewBox
        )
        XCTAssertEqual(docPoint.x, 50, accuracy: 0.01)
        XCTAssertEqual(docPoint.y, 50, accuracy: 0.01)
    }

    func testScaledDownMapping() {
        let viewSize = CGSize(width: 50, height: 50)
        let viewBox = CGRect(x: 0, y: 0, width: 100, height: 100)

        let docPoint = SVGCoordinateMapper.viewToDocument(
            point: CGPoint(x: 25, y: 25), viewSize: viewSize, viewBox: viewBox
        )
        XCTAssertEqual(docPoint.x, 50, accuracy: 0.01)
        XCTAssertEqual(docPoint.y, 50, accuracy: 0.01)
    }

    // MARK: - [I] Inverse Relationships

    func testRoundTripViewToDocumentAndBack() {
        let viewSize = CGSize(width: 300, height: 200)
        let viewBox = CGRect(x: 10, y: 20, width: 150, height: 100)
        let original = CGPoint(x: 120, y: 80)

        let doc = SVGCoordinateMapper.viewToDocument(
            point: original, viewSize: viewSize, viewBox: viewBox
        )
        let back = SVGCoordinateMapper.documentToView(
            point: doc, viewSize: viewSize, viewBox: viewBox
        )
        XCTAssertEqual(back.x, original.x, accuracy: 0.01)
        XCTAssertEqual(back.y, original.y, accuracy: 0.01)
    }

    func testRoundTripDocumentToViewAndBack() {
        let viewSize = CGSize(width: 400, height: 300)
        let viewBox = CGRect(x: 0, y: 0, width: 200, height: 150)
        let original = CGPoint(x: 75, y: 50)

        let view = SVGCoordinateMapper.documentToView(
            point: original, viewSize: viewSize, viewBox: viewBox
        )
        let back = SVGCoordinateMapper.viewToDocument(
            point: view, viewSize: viewSize, viewBox: viewBox
        )
        XCTAssertEqual(back.x, original.x, accuracy: 0.01)
        XCTAssertEqual(back.y, original.y, accuracy: 0.01)
    }

    // MARK: - [Right] currentScale

    func testCurrentScaleIdentity() {
        let scale = SVGCoordinateMapper.currentScale(
            viewSize: CGSize(width: 100, height: 100),
            viewBox: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        XCTAssertEqual(scale, 1, accuracy: 0.01)
    }

    func testCurrentScaleDoubled() {
        let scale = SVGCoordinateMapper.currentScale(
            viewSize: CGSize(width: 200, height: 200),
            viewBox: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        XCTAssertEqual(scale, 2, accuracy: 0.01)
    }

    func testCurrentScaleAspectRatioUsesMinimum() {
        let scale = SVGCoordinateMapper.currentScale(
            viewSize: CGSize(width: 400, height: 200),
            viewBox: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        XCTAssertEqual(scale, 2, accuracy: 0.01)
    }

    // MARK: - [B] Boundary Conditions

    func testCurrentScaleZeroViewBox() {
        let scale = SVGCoordinateMapper.currentScale(
            viewSize: CGSize(width: 100, height: 100),
            viewBox: CGRect(x: 0, y: 0, width: 0, height: 0)
        )
        XCTAssertEqual(scale, 1)
    }

    func testViewToDocumentZeroViewBox() {
        let point = CGPoint(x: 50, y: 50)
        let result = SVGCoordinateMapper.viewToDocument(
            point: point,
            viewSize: CGSize(width: 100, height: 100),
            viewBox: CGRect(x: 0, y: 0, width: 0, height: 0)
        )
        XCTAssertEqual(result.x, 50, accuracy: 0.01)
        XCTAssertEqual(result.y, 50, accuracy: 0.01)
    }

    func testOriginPoint() {
        let result = SVGCoordinateMapper.viewToDocument(
            point: .zero,
            viewSize: CGSize(width: 100, height: 100),
            viewBox: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        XCTAssertEqual(result.x, 0, accuracy: 0.01)
        XCTAssertEqual(result.y, 0, accuracy: 0.01)
    }

    // MARK: - [Right] documentToView for rect

    func testDocumentToViewRect() {
        let viewSize = CGSize(width: 200, height: 200)
        let viewBox = CGRect(x: 0, y: 0, width: 100, height: 100)
        let docRect = CGRect(x: 10, y: 10, width: 20, height: 20)

        let viewRect = SVGCoordinateMapper.documentToView(
            rect: docRect, viewSize: viewSize, viewBox: viewBox
        )
        XCTAssertEqual(viewRect.origin.x, 20, accuracy: 0.01)
        XCTAssertEqual(viewRect.origin.y, 20, accuracy: 0.01)
        XCTAssertEqual(viewRect.width, 40, accuracy: 0.01)
        XCTAssertEqual(viewRect.height, 40, accuracy: 0.01)
    }

    // MARK: - [Right] Non-zero origin viewBox

    func testNonZeroOriginViewBox() {
        let viewSize = CGSize(width: 100, height: 100)
        let viewBox = CGRect(x: 50, y: 50, width: 100, height: 100)

        let viewPoint = SVGCoordinateMapper.documentToView(
            point: CGPoint(x: 50, y: 50), viewSize: viewSize, viewBox: viewBox
        )
        XCTAssertEqual(viewPoint.x, 0, accuracy: 0.01)
        XCTAssertEqual(viewPoint.y, 0, accuracy: 0.01)
    }

    // MARK: - [P] Performance

    func testCoordinateMappingPerformance() {
        let viewSize = CGSize(width: 800, height: 600)
        let viewBox = CGRect(x: 0, y: 0, width: 1000, height: 750)

        measure {
            for i in 0..<10000 {
                let point = CGPoint(x: CGFloat(i % 800), y: CGFloat(i % 600))
                _ = SVGCoordinateMapper.viewToDocument(
                    point: point, viewSize: viewSize, viewBox: viewBox
                )
            }
        }
    }
}
