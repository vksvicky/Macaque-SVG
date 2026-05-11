import CoreGraphics
import SwiftUI
import XCTest

@testable import MacaqueSVG

final class SVGPathDataParserTests: XCTestCase {
    func testMoveLineClose() {
        let path = SVGPathDataParser.path(from: "M0 0 L10 0 L10 10 Z")
        XCTAssertFalse(path.isEmpty)
        let bounds = path.boundingRect
        XCTAssertEqual(bounds.origin.x, 0, accuracy: 0.01)
        XCTAssertEqual(bounds.origin.y, 0, accuracy: 0.01)
        XCTAssertEqual(bounds.size.width, 10, accuracy: 0.01)
        XCTAssertEqual(bounds.size.height, 10, accuracy: 0.01)
    }

    func testHorizontalVerticalRelative() {
        let path = SVGPathDataParser.path(from: "M5 5 h10 v10 H0 V0 z")
        XCTAssertFalse(path.isEmpty)
    }

    func testQuadraticCurve() {
        let path = SVGPathDataParser.path(from: "M0 10 Q 5 0 10 10")
        XCTAssertFalse(path.isEmpty)
    }
}
