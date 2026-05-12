import SwiftUI
import XCTest

@testable import MacaqueSVG

final class SVGPathLengthSamplerTests: XCTestCase {
    private let epsilon: CGFloat = 0.001

    // MARK: - [Right] Basic sampling

    func testStraightLineTotalDistance() {
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 10, y: 0))

        let result = SVGPathLengthSampler.samples(from: path)
        guard let last = result.last else {
            return XCTFail("Expected at least one sample")
        }
        XCTAssertEqual(last.distance, 10, accuracy: epsilon)
    }

    func testSquarePathTotalDistanceIs40() {
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 10, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        path.addLine(to: CGPoint(x: 0, y: 10))
        path.closeSubpath()

        let result = SVGPathLengthSampler.samples(from: path)
        guard let last = result.last else {
            return XCTFail("Expected samples")
        }
        XCTAssertEqual(last.distance, 40, accuracy: epsilon)
    }

    // MARK: - [Right] pointAndAngle

    func testPointAndAngleAtDistanceZeroReturnsStart() {
        var path = Path()
        path.move(to: CGPoint(x: 5, y: 5))
        path.addLine(to: CGPoint(x: 15, y: 5))

        let samples = SVGPathLengthSampler.samples(from: path)
        guard let (point, _) = SVGPathLengthSampler.pointAndAngle(samples: samples, atDistance: 0) else {
            return XCTFail("Expected result")
        }
        XCTAssertEqual(point.x, 5, accuracy: epsilon)
        XCTAssertEqual(point.y, 5, accuracy: epsilon)
    }

    func testPointAndAngleAtHalfDistanceReturnsMidpoint() {
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 20, y: 0))

        let samples = SVGPathLengthSampler.samples(from: path)
        guard let (point, _) = SVGPathLengthSampler.pointAndAngle(samples: samples, atDistance: 10) else {
            return XCTFail("Expected result")
        }
        XCTAssertEqual(point.x, 10, accuracy: epsilon)
        XCTAssertEqual(point.y, 0, accuracy: epsilon)
    }

    // MARK: - [B] Boundary conditions

    func testEmptyPathReturnsEmptySamples() {
        let path = Path()
        let result = SVGPathLengthSampler.samples(from: path)
        XCTAssertTrue(result.isEmpty)
    }

    func testSingleMoveOnlyPath() {
        var path = Path()
        path.move(to: CGPoint(x: 3, y: 4))

        let result = SVGPathLengthSampler.samples(from: path)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.distance, 0)
    }

    func testPointAndAngleReturnsNilForEmptySamples() {
        let result = SVGPathLengthSampler.pointAndAngle(samples: [], atDistance: 5)
        XCTAssertNil(result)
    }

    func testNegativeDistanceClampsToZero() {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 0))

        let samples = SVGPathLengthSampler.samples(from: path)
        guard let (point, _) = SVGPathLengthSampler.pointAndAngle(samples: samples, atDistance: -5) else {
            return XCTFail("Expected result")
        }
        XCTAssertEqual(point.x, 0, accuracy: epsilon)
        XCTAssertEqual(point.y, 0, accuracy: epsilon)
    }

    func testDistancePastTotalClampsToEnd() {
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 10, y: 0))

        let samples = SVGPathLengthSampler.samples(from: path)
        guard let (point, _) = SVGPathLengthSampler.pointAndAngle(samples: samples, atDistance: 999) else {
            return XCTFail("Expected result")
        }
        XCTAssertEqual(point.x, 10, accuracy: epsilon)
        XCTAssertEqual(point.y, 0, accuracy: epsilon)
    }

    // MARK: - [Right] Curves

    func testCubicCurveGeneratesMultipleSamples() {
        var path = Path()
        path.move(to: .zero)
        path.addCurve(
            to: CGPoint(x: 10, y: 0),
            control1: CGPoint(x: 3, y: 5),
            control2: CGPoint(x: 7, y: 5)
        )

        let result = SVGPathLengthSampler.samples(from: path)
        XCTAssertGreaterThan(result.count, 2)
    }

    func testQuadCurveGeneratesMultipleSamples() {
        var path = Path()
        path.move(to: .zero)
        path.addQuadCurve(
            to: CGPoint(x: 10, y: 0),
            control: CGPoint(x: 5, y: 10)
        )

        let result = SVGPathLengthSampler.samples(from: path)
        XCTAssertGreaterThan(result.count, 2)
    }

    // MARK: - [Right] Angles

    func testHorizontalLineAngleIsZero() {
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 10, y: 0))

        let samples = SVGPathLengthSampler.samples(from: path)
        guard let last = samples.last else {
            return XCTFail("Expected samples")
        }
        XCTAssertEqual(last.angle, 0, accuracy: epsilon)
    }

    func testVerticalLineAngleIsPiOverTwo() {
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 0, y: 10))

        let samples = SVGPathLengthSampler.samples(from: path)
        guard let last = samples.last else {
            return XCTFail("Expected samples")
        }
        XCTAssertEqual(last.angle, .pi / 2, accuracy: epsilon)
    }

    // MARK: - [P] Performance: curveSteps parameter

    func testSampleCountScalesWithCurveSteps() {
        var path = Path()
        path.move(to: .zero)
        path.addCurve(
            to: CGPoint(x: 10, y: 0),
            control1: CGPoint(x: 3, y: 5),
            control2: CGPoint(x: 7, y: 5)
        )

        let low = SVGPathLengthSampler.samples(from: path, curveSteps: 4)
        let high = SVGPathLengthSampler.samples(from: path, curveSteps: 20)
        XCTAssertGreaterThan(high.count, low.count)
    }
}
