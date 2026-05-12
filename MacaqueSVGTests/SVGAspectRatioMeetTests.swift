import XCTest

@testable import MacaqueSVG

final class SVGAspectRatioMeetTests: XCTestCase {
    private let epsilon: CGFloat = 0.001

    private let container = CGRect(x: 0, y: 0, width: 200, height: 100)
    private let square = CGSize(width: 100, height: 100)

    // MARK: - [Right] Default (xMidYMid meet)

    func testDefaultCentersMeetScaling() {
        let rect = SVGAspectRatioMeet.destinationRect(
            container: container,
            intrinsicSize: square,
            preserveAspectRatio: nil
        )
        XCTAssertEqual(rect.width, 100, accuracy: epsilon)
        XCTAssertEqual(rect.height, 100, accuracy: epsilon)
        XCTAssertEqual(rect.midX, 100, accuracy: epsilon)
        XCTAssertEqual(rect.midY, 50, accuracy: epsilon)
    }

    func testExplicitXMidYMidMeet() {
        let rect = SVGAspectRatioMeet.destinationRect(
            container: container,
            intrinsicSize: square,
            preserveAspectRatio: "xMidYMid meet"
        )
        XCTAssertEqual(rect.width, 100, accuracy: epsilon)
        XCTAssertEqual(rect.height, 100, accuracy: epsilon)
        XCTAssertEqual(rect.midX, container.midX, accuracy: epsilon)
    }

    // MARK: - [Right] Alignment variants

    func testXMinYMinMeet() {
        let rect = SVGAspectRatioMeet.destinationRect(
            container: container,
            intrinsicSize: square,
            preserveAspectRatio: "xMinYMin meet"
        )
        XCTAssertEqual(rect.origin.x, 0, accuracy: epsilon)
        XCTAssertEqual(rect.origin.y, 0, accuracy: epsilon)
    }

    func testXMaxYMaxMeet() {
        let rect = SVGAspectRatioMeet.destinationRect(
            container: container,
            intrinsicSize: square,
            preserveAspectRatio: "xMaxYMax meet"
        )
        XCTAssertEqual(rect.maxX, container.maxX, accuracy: epsilon)
        XCTAssertEqual(rect.maxY, container.maxY, accuracy: epsilon)
    }

    func testXMinYMaxMeet() {
        let rect = SVGAspectRatioMeet.destinationRect(
            container: container,
            intrinsicSize: square,
            preserveAspectRatio: "xMinYMax meet"
        )
        XCTAssertEqual(rect.origin.x, 0, accuracy: epsilon)
        XCTAssertEqual(rect.maxY, container.maxY, accuracy: epsilon)
    }

    // MARK: - [Right] Slice mode

    func testSliceUsesMaxScale() {
        let rect = SVGAspectRatioMeet.destinationRect(
            container: container,
            intrinsicSize: square,
            preserveAspectRatio: "xMidYMid slice"
        )
        XCTAssertEqual(rect.width, 200, accuracy: epsilon)
        XCTAssertEqual(rect.height, 200, accuracy: epsilon)
    }

    // MARK: - [Right] Exact fit (no scaling needed)

    func testExactFitReturnsContainerRect() {
        let rect = SVGAspectRatioMeet.destinationRect(
            container: container,
            intrinsicSize: CGSize(width: 200, height: 100),
            preserveAspectRatio: "xMidYMid meet"
        )
        XCTAssertEqual(rect.width, 200, accuracy: epsilon)
        XCTAssertEqual(rect.height, 100, accuracy: epsilon)
    }

    // MARK: - [Right] Portrait intrinsic in landscape container

    func testPortraitIntrinsicInLandscapeContainer() {
        let rect = SVGAspectRatioMeet.destinationRect(
            container: container,
            intrinsicSize: CGSize(width: 50, height: 200),
            preserveAspectRatio: "xMidYMid meet"
        )
        let expectedScale = min(200.0 / 50.0, 100.0 / 200.0)
        XCTAssertEqual(rect.width, 50 * expectedScale, accuracy: epsilon)
        XCTAssertEqual(rect.height, 200 * expectedScale, accuracy: epsilon)
    }

    // MARK: - [B] Boundary: zero-size intrinsic

    func testZeroWidthIntrinsicReturnsContainer() {
        let rect = SVGAspectRatioMeet.destinationRect(
            container: container,
            intrinsicSize: CGSize(width: 0, height: 100),
            preserveAspectRatio: nil
        )
        XCTAssertEqual(rect, container)
    }

    func testZeroHeightIntrinsicReturnsContainer() {
        let rect = SVGAspectRatioMeet.destinationRect(
            container: container,
            intrinsicSize: CGSize(width: 100, height: 0),
            preserveAspectRatio: nil
        )
        XCTAssertEqual(rect, container)
    }

    // MARK: - [B] Boundary: zero-size container

    func testZeroSizeContainerReturnsContainer() {
        let empty = CGRect(x: 0, y: 0, width: 0, height: 0)
        let rect = SVGAspectRatioMeet.destinationRect(
            container: empty,
            intrinsicSize: square,
            preserveAspectRatio: nil
        )
        XCTAssertEqual(rect, empty)
    }

    // MARK: - [B] Boundary: empty / whitespace preserveAspectRatio

    func testEmptyStringDefaultsToMidMid() {
        let rect = SVGAspectRatioMeet.destinationRect(
            container: container,
            intrinsicSize: square,
            preserveAspectRatio: ""
        )
        XCTAssertEqual(rect.width, 100, accuracy: epsilon)
        XCTAssertEqual(rect.height, 100, accuracy: epsilon)
    }

    func testWhitespaceOnlyDefaultsToMidMid() {
        let rect = SVGAspectRatioMeet.destinationRect(
            container: container,
            intrinsicSize: square,
            preserveAspectRatio: "   "
        )
        XCTAssertEqual(rect.width, 100, accuracy: epsilon)
        XCTAssertEqual(rect.height, 100, accuracy: epsilon)
    }

    // MARK: - [B] Non-origin container

    func testNonOriginContainerOffsetsCorrectly() {
        let offset = CGRect(x: 50, y: 50, width: 200, height: 100)
        let rect = SVGAspectRatioMeet.destinationRect(
            container: offset,
            intrinsicSize: square,
            preserveAspectRatio: "xMinYMin meet"
        )
        XCTAssertEqual(rect.origin.x, 50, accuracy: epsilon)
        XCTAssertEqual(rect.origin.y, 50, accuracy: epsilon)
    }

    // MARK: - [I] Inverse: meet and slice are complementary

    func testMeetScaleIsNotGreaterThanSliceScale() {
        let meetRect = SVGAspectRatioMeet.destinationRect(
            container: container,
            intrinsicSize: square,
            preserveAspectRatio: "xMidYMid meet"
        )
        let sliceRect = SVGAspectRatioMeet.destinationRect(
            container: container,
            intrinsicSize: square,
            preserveAspectRatio: "xMidYMid slice"
        )
        XCTAssertLessThanOrEqual(meetRect.width, sliceRect.width + epsilon)
        XCTAssertLessThanOrEqual(meetRect.height, sliceRect.height + epsilon)
    }

    // MARK: - [Right] Case insensitivity

    func testCaseInsensitiveAlignment() {
        let rect = SVGAspectRatioMeet.destinationRect(
            container: container,
            intrinsicSize: square,
            preserveAspectRatio: "XMIDYMID MEET"
        )
        XCTAssertEqual(rect.width, 100, accuracy: epsilon)
        XCTAssertEqual(rect.midX, container.midX, accuracy: epsilon)
    }
}
