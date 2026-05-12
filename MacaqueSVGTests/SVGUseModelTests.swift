import CoreGraphics
import XCTest

@testable import MacaqueSVG

final class SVGUseModelTests: XCTestCase {

    // MARK: - [Right] SVGUse

    func testUseInitWithFragment() {
        let use = SVGUse(hrefFragment: "logo", x: 10, y: 20)
        XCTAssertEqual(use.hrefFragment, "logo")
        XCTAssertEqual(use.x, 10)
        XCTAssertEqual(use.y, 20)
        XCTAssertNil(use.useWidth)
        XCTAssertNil(use.useHeight)
    }

    func testUseWithOptionalSize() {
        let use = SVGUse(hrefFragment: "icon", useWidth: 50, useHeight: 50)
        XCTAssertEqual(use.useWidth, 50)
        XCTAssertEqual(use.useHeight, 50)
    }

    // MARK: - [Right] SVGUseAttributeParsing

    func testHrefFragmentFromHash() {
        let fragment = SVGUseAttributeParsing.hrefFragment(from: ["href": "#myId"])
        XCTAssertEqual(fragment, "myId")
    }

    func testHrefFragmentFromXlinkHref() {
        let fragment = SVGUseAttributeParsing.hrefFragment(from: ["xlink:href": "#linked"])
        XCTAssertEqual(fragment, "linked")
    }

    func testHrefFragmentFromFullNamespace() {
        let fragment = SVGUseAttributeParsing.hrefFragment(
            from: ["{http://www.w3.org/1999/xlink}href": "#ns"]
        )
        XCTAssertEqual(fragment, "ns")
    }

    func testHrefFragmentNoHashReturnsNil() {
        let fragment = SVGUseAttributeParsing.hrefFragment(from: ["href": "noHash"])
        XCTAssertNil(fragment)
    }

    // MARK: - [B] Boundary Conditions

    func testHrefFragmentEmptyReturnsNil() {
        XCTAssertNil(SVGUseAttributeParsing.hrefFragment(from: [:]))
    }

    func testHrefFragmentWhitespaceReturnsNil() {
        XCTAssertNil(SVGUseAttributeParsing.hrefFragment(from: ["href": "   "]))
    }

    func testHrefFragmentWithUrlAndHash() {
        let fragment = SVGUseAttributeParsing.hrefFragment(from: ["href": "file.svg#element"])
        XCTAssertEqual(fragment, "element")
    }

    // MARK: - [I] Inverse Relationships

    func testUseIsElement() {
        let use = SVGUse(hrefFragment: "test", svgId: "useEl")
        XCTAssertEqual(use.svgId, "useEl")
        XCTAssertNotNil(use.nodeID)
    }

    // MARK: - [E] Error Conditions

    func testHrefFragmentPrioritizesHrefOverXlink() {
        let fragment = SVGUseAttributeParsing.hrefFragment(
            from: ["href": "#primary", "xlink:href": "#fallback"]
        )
        XCTAssertEqual(fragment, "primary")
    }
}
