import CoreGraphics
import SwiftUI
import XCTest

@testable import MacaqueSVG

final class SVGPathDataParserExtendedTests: XCTestCase {

    // MARK: - [Right] Arc commands

    func testArcAbsoluteProducesPath() {
        let path = SVGPathDataParser.path(from: "M10 80 A 25 25 0 0 1 50 80")
        XCTAssertFalse(path.isEmpty)
        let bounds = path.boundingRect
        XCTAssertGreaterThan(bounds.width, 0)
        XCTAssertGreaterThan(bounds.height, 0)
    }

    func testArcRelativeProducesPath() {
        let path = SVGPathDataParser.path(from: "M10 80 a 25 25 0 0 1 40 0")
        XCTAssertFalse(path.isEmpty)
    }

    // MARK: - [Right] Smooth cubic

    func testSmoothCubicAbsolute() {
        let path = SVGPathDataParser.path(from: "M10 80 C 40 10 65 10 95 80 S 150 150 180 80")
        XCTAssertFalse(path.isEmpty)
    }

    func testSmoothCubicRelative() {
        let path = SVGPathDataParser.path(from: "M10 80 c 30 -70 55 -70 85 0 s 55 70 85 0")
        XCTAssertFalse(path.isEmpty)
    }

    // MARK: - [Right] Smooth quadratic

    func testSmoothQuadraticAbsolute() {
        let path = SVGPathDataParser.path(from: "M10 80 Q 52.5 10 95 80 T 180 80")
        XCTAssertFalse(path.isEmpty)
    }

    func testSmoothQuadraticRelative() {
        let path = SVGPathDataParser.path(from: "M10 80 q 42.5 -70 85 0 t 85 0")
        XCTAssertFalse(path.isEmpty)
    }

    // MARK: - [Right] Cubic curves

    func testCubicAbsolute() {
        let path = SVGPathDataParser.path(from: "M10 10 C 20 20 40 20 50 10")
        XCTAssertFalse(path.isEmpty)
    }

    func testCubicRelative() {
        let path = SVGPathDataParser.path(from: "M10 10 c 10 10 30 10 40 0")
        XCTAssertFalse(path.isEmpty)
    }

    // MARK: - [Right] Close subpath

    func testCloseSubpathRestoresStart() {
        let path = SVGPathDataParser.path(from: "M10 10 L20 10 L20 20 Z")
        XCTAssertFalse(path.isEmpty)
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.width, 10, accuracy: 0.01)
    }

    // MARK: - [Right] Implicit line after move

    func testImplicitLineAfterMove() {
        let path = SVGPathDataParser.path(from: "M0 0 10 10 20 0")
        XCTAssertFalse(path.isEmpty)
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.width, 20, accuracy: 0.01)
    }

    // MARK: - [B] Boundary Conditions

    func testEmptyStringProducesEmptyPath() {
        let path = SVGPathDataParser.path(from: "")
        XCTAssertTrue(path.isEmpty)
    }

    func testWhitespaceOnlyProducesEmptyPath() {
        let path = SVGPathDataParser.path(from: "   \n\t  ")
        XCTAssertTrue(path.isEmpty)
    }

    func testSingleMoveProducesPath() {
        let path = SVGPathDataParser.path(from: "M5 5")
        XCTAssertFalse(path.isEmpty)
    }

    func testNegativeCoordinates() {
        let path = SVGPathDataParser.path(from: "M-10 -20 L10 20")
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.origin.x, -10, accuracy: 0.01)
        XCTAssertEqual(bounds.origin.y, -20, accuracy: 0.01)
    }

    func testCommaDelimitedCoordinates() {
        let path = SVGPathDataParser.path(from: "M0,0 L10,0 L10,10 Z")
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.width, 10, accuracy: 0.01)
    }

    // MARK: - [Right] Vertical and horizontal

    func testVerticalAbsolute() {
        let path = SVGPathDataParser.path(from: "M0 0 V10")
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.height, 10, accuracy: 0.01)
    }

    func testVerticalRelative() {
        let path = SVGPathDataParser.path(from: "M0 0 v10")
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.height, 10, accuracy: 0.01)
    }

    func testHorizontalAbsolute() {
        let path = SVGPathDataParser.path(from: "M0 0 H10")
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.width, 10, accuracy: 0.01)
    }

    // MARK: - [E] Error Conditions

    func testInvalidCommandLetterSkipped() {
        let path = SVGPathDataParser.path(from: "M0 0 X10 L10 10")
        XCTAssertFalse(path.isEmpty)
    }

    func testArcWithZeroRadiiDegeneratesToLine() {
        let path = SVGPathDataParser.path(from: "M0 0 A 0 0 0 0 1 10 10")
        XCTAssertFalse(path.isEmpty)
    }

    // MARK: - [P] Performance

    func testLargePathParsesQuickly() {
        var d = "M0 0"
        for i in 1...500 {
            d += " L\(i) \(i % 100)"
        }
        measure {
            _ = SVGPathDataParser.path(from: d)
        }
    }
}
