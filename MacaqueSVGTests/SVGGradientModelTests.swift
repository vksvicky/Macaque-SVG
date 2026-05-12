import CoreGraphics
import SwiftUI
import XCTest

@testable import MacaqueSVG

final class SVGGradientModelTests: XCTestCase {

    // MARK: - [Right] SVGLinearGradientDef

    func testLinearGradientDefaults() {
        let gradient = SVGLinearGradientDef()
        XCTAssertEqual(gradient.x1, 0)
        XCTAssertEqual(gradient.y1, 0)
        XCTAssertEqual(gradient.x2, 1)
        XCTAssertEqual(gradient.y2, 0)
        XCTAssertEqual(gradient.gradientUnits, "objectBoundingBox")
        XCTAssertTrue(gradient.stops.isEmpty)
    }

    func testLinearGradientAppendStop() {
        let gradient = SVGLinearGradientDef(svgId: "lg1")
        gradient.appendStop(SVGGradientStop(offset: 0, color: .red))
        gradient.appendStop(SVGGradientStop(offset: 1, color: .blue))
        XCTAssertEqual(gradient.stops.count, 2)
        XCTAssertEqual(gradient.stops[0].offset, 0)
        XCTAssertEqual(gradient.stops[1].offset, 1)
    }

    func testLinearGradientCustomCoordinates() {
        let gradient = SVGLinearGradientDef(
            x1: 0.2, y1: 0.3, x2: 0.8, y2: 0.9,
            gradientUnits: "userSpaceOnUse"
        )
        XCTAssertEqual(gradient.x1, 0.2)
        XCTAssertEqual(gradient.y1, 0.3)
        XCTAssertEqual(gradient.x2, 0.8)
        XCTAssertEqual(gradient.y2, 0.9)
        XCTAssertEqual(gradient.gradientUnits, "userSpaceOnUse")
    }

    // MARK: - [Right] SVGRadialGradientDef

    func testRadialGradientDefaults() {
        let gradient = SVGRadialGradientDef()
        XCTAssertEqual(gradient.cx, 0.5)
        XCTAssertEqual(gradient.cy, 0.5)
        XCTAssertEqual(gradient.r, 0.5)
        XCTAssertEqual(gradient.gradientUnits, "objectBoundingBox")
        XCTAssertTrue(gradient.stops.isEmpty)
    }

    func testRadialGradientAppendStop() {
        let gradient = SVGRadialGradientDef(svgId: "rg1")
        gradient.appendStop(SVGGradientStop(offset: 0, color: .white))
        gradient.appendStop(SVGGradientStop(offset: 0.5, color: .gray))
        gradient.appendStop(SVGGradientStop(offset: 1, color: .black))
        XCTAssertEqual(gradient.stops.count, 3)
        XCTAssertEqual(gradient.stops[1].offset, 0.5)
    }

    // MARK: - [B] Boundary Conditions

    func testGradientStopAtBoundaryOffsets() {
        let gradient = SVGLinearGradientDef()
        gradient.appendStop(SVGGradientStop(offset: -0.1, color: .red))
        gradient.appendStop(SVGGradientStop(offset: 1.5, color: .blue))
        XCTAssertEqual(gradient.stops.count, 2)
        XCTAssertEqual(gradient.stops[0].offset, -0.1)
        XCTAssertEqual(gradient.stops[1].offset, 1.5)
    }

    func testGradientWithNoStops() {
        let gradient = SVGLinearGradientDef()
        XCTAssertTrue(gradient.stops.isEmpty)
    }

    // MARK: - [Right] SVGGradientStop

    func testGradientStopProperties() {
        let stop = SVGGradientStop(offset: 0.75, color: .green)
        XCTAssertEqual(stop.offset, 0.75)
    }

    // MARK: - [I] Gradients are SVGElements

    func testLinearGradientIsElement() {
        let gradient = SVGLinearGradientDef(svgId: "testGrad")
        XCTAssertEqual(gradient.svgId, "testGrad")
        XCTAssertNotNil(gradient.nodeID)
    }

    func testRadialGradientIsElement() {
        let gradient = SVGRadialGradientDef(svgId: "radGrad")
        XCTAssertEqual(gradient.svgId, "radGrad")
        XCTAssertNotNil(gradient.nodeID)
    }
}
