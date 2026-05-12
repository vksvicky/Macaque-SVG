import XCTest
@testable import MacaqueSVG

final class SVGViewBoxMappingTests: XCTestCase {

    private let accuracy: CGFloat = 0.0001

    // MARK: - [Right] Are the Results Right?

    func testIdentityViewBox() {
        let t = SVGViewBoxMapping.userSpaceToView(
            viewSize: CGSize(width: 100, height: 100),
            viewBox: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        XCTAssertEqual(t.a, 1, accuracy: accuracy)
        XCTAssertEqual(t.d, 1, accuracy: accuracy)
        XCTAssertEqual(t.tx, 0, accuracy: accuracy)
        XCTAssertEqual(t.ty, 0, accuracy: accuracy)
    }

    func testScalingDown() {
        let t = SVGViewBoxMapping.userSpaceToView(
            viewSize: CGSize(width: 50, height: 50),
            viewBox: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        XCTAssertEqual(t.a, 0.5, accuracy: accuracy)
        XCTAssertEqual(t.d, 0.5, accuracy: accuracy)
    }

    func testScalingUp() {
        let t = SVGViewBoxMapping.userSpaceToView(
            viewSize: CGSize(width: 200, height: 200),
            viewBox: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        XCTAssertEqual(t.a, 2, accuracy: accuracy)
        XCTAssertEqual(t.d, 2, accuracy: accuracy)
    }

    func testNonZeroOriginViewBox() {
        let t = SVGViewBoxMapping.userSpaceToView(
            viewSize: CGSize(width: 100, height: 100),
            viewBox: CGRect(x: 10, y: 20, width: 100, height: 100)
        )
        XCTAssertEqual(t.a, 1, accuracy: accuracy)
        XCTAssertEqual(t.d, 1, accuracy: accuracy)
        XCTAssertEqual(t.tx, -10, accuracy: accuracy)
        XCTAssertEqual(t.ty, -20, accuracy: accuracy)
    }

    func testAspectRatioPreservedXMidYMidMeet() {
        let t = SVGViewBoxMapping.userSpaceToView(
            viewSize: CGSize(width: 200, height: 100),
            viewBox: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        let scale = min(200.0 / 100.0, 100.0 / 100.0)
        XCTAssertEqual(scale, 1.0)
        XCTAssertEqual(t.a, scale, accuracy: accuracy)
        XCTAssertEqual(t.d, scale, accuracy: accuracy)
        let expectedTx = (200 - 100 * scale) / 2
        XCTAssertEqual(t.tx, expectedTx, accuracy: accuracy, "Centered horizontally")
    }

    func testWideViewBoxInTallView() {
        let t = SVGViewBoxMapping.userSpaceToView(
            viewSize: CGSize(width: 100, height: 200),
            viewBox: CGRect(x: 0, y: 0, width: 200, height: 100)
        )
        let scale = min(100.0 / 200.0, 200.0 / 100.0)
        XCTAssertEqual(t.a, scale, accuracy: accuracy)
        XCTAssertEqual(t.d, scale, accuracy: accuracy)
    }

    // MARK: - [B] Boundary Conditions

    func testZeroSizeViewBoxReturnsIdentity() {
        let t = SVGViewBoxMapping.userSpaceToView(
            viewSize: CGSize(width: 100, height: 100),
            viewBox: CGRect(x: 0, y: 0, width: 0, height: 0)
        )
        XCTAssertEqual(t, .identity)
    }

    func testZeroWidthViewBoxReturnsIdentity() {
        let t = SVGViewBoxMapping.userSpaceToView(
            viewSize: CGSize(width: 100, height: 100),
            viewBox: CGRect(x: 0, y: 0, width: 0, height: 50)
        )
        XCTAssertEqual(t, .identity)
    }

    func testZeroHeightViewBoxReturnsIdentity() {
        let t = SVGViewBoxMapping.userSpaceToView(
            viewSize: CGSize(width: 100, height: 100),
            viewBox: CGRect(x: 0, y: 0, width: 50, height: 0)
        )
        XCTAssertEqual(t, .identity)
    }

    func testVerySmallViewSize() {
        let t = SVGViewBoxMapping.userSpaceToView(
            viewSize: CGSize(width: 0.5, height: 0.5),
            viewBox: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        XCTAssertEqual(t.a, 1.0 / 100.0, accuracy: accuracy, "View clamps to min 1px")
        XCTAssertEqual(t.d, 1.0 / 100.0, accuracy: accuracy)
    }

    // MARK: - [P] Performance / Determinism

    func testTransformComputationIsDeterministic() {
        let viewSize = CGSize(width: 300, height: 150)
        let viewBox = CGRect(x: 5, y: 10, width: 80, height: 60)

        let t1 = SVGViewBoxMapping.userSpaceToView(viewSize: viewSize, viewBox: viewBox)
        let t2 = SVGViewBoxMapping.userSpaceToView(viewSize: viewSize, viewBox: viewBox)

        XCTAssertEqual(t1.a, t2.a)
        XCTAssertEqual(t1.b, t2.b)
        XCTAssertEqual(t1.c, t2.c)
        XCTAssertEqual(t1.d, t2.d)
        XCTAssertEqual(t1.tx, t2.tx)
        XCTAssertEqual(t1.ty, t2.ty)
    }

    func testScaleAndTranslateConsistency() {
        let viewSize = CGSize(width: 400, height: 400)
        let viewBox = CGRect(x: 50, y: 50, width: 200, height: 200)

        let t = SVGViewBoxMapping.userSpaceToView(viewSize: viewSize, viewBox: viewBox)
        let scale = min(400.0 / 200.0, 400.0 / 200.0)

        XCTAssertEqual(t.a, scale, accuracy: accuracy)
        let expectedTx = (400.0 - 200.0 * scale) / 2.0 - 50.0 * scale
        let expectedTy = (400.0 - 200.0 * scale) / 2.0 - 50.0 * scale
        XCTAssertEqual(t.tx, expectedTx, accuracy: accuracy)
        XCTAssertEqual(t.ty, expectedTy, accuracy: accuracy)
    }
}
