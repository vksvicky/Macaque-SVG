import XCTest

@testable import MacaqueSVG

final class EditorToolTests: XCTestCase {

    // MARK: - Right Results

    func testSelectToolAlwaysPans() {
        let element = SVGRect(x: 10, y: 10, width: 50, height: 50)
        var panOffset = CGSize(width: 100, height: 200)
        var revisionCounter = 0

        EditorTool.handleDrag(
            tool: .select,
            dragTranslation: CGSize(width: 15, height: -10),
            selectedElement: element,
            panOffset: &panOffset,
            revisionCounter: &revisionCounter
        )

        XCTAssertEqual(panOffset.width, 115)
        XCTAssertEqual(panOffset.height, 190)
    }

    func testMoveToolTranslatesSelectedElement() {
        let element = SVGRect(x: 0, y: 0, width: 100, height: 100)
        var panOffset = CGSize.zero
        var revisionCounter = 0

        EditorTool.handleDrag(
            tool: .move,
            dragTranslation: CGSize(width: 20, height: 30),
            selectedElement: element,
            panOffset: &panOffset,
            revisionCounter: &revisionCounter
        )

        XCTAssertEqual(element.transform.tx, 20)
        XCTAssertEqual(element.transform.ty, 30)
        XCTAssertEqual(panOffset, .zero)
    }

    func testMoveToolPansWhenNoSelection() {
        var panOffset = CGSize(width: 5, height: 5)
        var revisionCounter = 0

        EditorTool.handleDrag(
            tool: .move,
            dragTranslation: CGSize(width: 10, height: 10),
            selectedElement: nil,
            panOffset: &panOffset,
            revisionCounter: &revisionCounter
        )

        XCTAssertEqual(panOffset.width, 15)
        XCTAssertEqual(panOffset.height, 15)
    }

    func testDisplayNameValues() {
        for tool in EditorTool.allCases {
            XCTAssertFalse(tool.displayName.isEmpty)
        }
    }

    func testSystemImageValues() {
        for tool in EditorTool.allCases {
            XCTAssertFalse(tool.systemImage.isEmpty)
        }
    }

    func testShortcutKeyValues() {
        XCTAssertEqual(EditorTool.select.shortcutKey, "v")
        XCTAssertEqual(EditorTool.move.shortcutKey, "m")
    }

    // MARK: - Boundary Conditions

    func testHandleDragWithZeroTranslation() {
        let element = SVGRect(x: 5, y: 5, width: 20, height: 20)
        var panOffset = CGSize(width: 50, height: 50)
        var revisionCounter = 0

        EditorTool.handleDrag(
            tool: .select,
            dragTranslation: .zero,
            selectedElement: element,
            panOffset: &panOffset,
            revisionCounter: &revisionCounter
        )

        XCTAssertEqual(panOffset.width, 50)
        XCTAssertEqual(panOffset.height, 50)

        EditorTool.handleDrag(
            tool: .move,
            dragTranslation: .zero,
            selectedElement: element,
            panOffset: &panOffset,
            revisionCounter: &revisionCounter
        )

        XCTAssertEqual(element.transform.tx, 0)
        XCTAssertEqual(element.transform.ty, 0)
    }

    func testHandleDragWithNegativeTranslation() {
        let element = SVGRect(x: 0, y: 0, width: 10, height: 10)
        var panOffset = CGSize(width: 100, height: 100)
        var revisionCounter = 0

        EditorTool.handleDrag(
            tool: .move,
            dragTranslation: CGSize(width: -50, height: -75),
            selectedElement: element,
            panOffset: &panOffset,
            revisionCounter: &revisionCounter
        )

        XCTAssertEqual(element.transform.tx, -50)
        XCTAssertEqual(element.transform.ty, -75)
        XCTAssertEqual(panOffset.width, 100)
        XCTAssertEqual(panOffset.height, 100)
    }

    func testHandleDragWithLargeTranslation() {
        let element = SVGRect(x: 0, y: 0, width: 1, height: 1)
        var panOffset = CGSize.zero
        var revisionCounter = 0
        let largeValue: CGFloat = 1_000_000

        EditorTool.handleDrag(
            tool: .move,
            dragTranslation: CGSize(width: largeValue, height: largeValue),
            selectedElement: element,
            panOffset: &panOffset,
            revisionCounter: &revisionCounter
        )

        XCTAssertEqual(element.transform.tx, largeValue)
        XCTAssertEqual(element.transform.ty, largeValue)
    }

    // MARK: - Cross-Checking

    func testSelectToolDoesNotModifyElement() {
        let element = SVGRect(x: 10, y: 20, width: 30, height: 40)
        let originalTransform = element.transform
        var panOffset = CGSize.zero
        var revisionCounter = 0

        EditorTool.handleDrag(
            tool: .select,
            dragTranslation: CGSize(width: 99, height: 99),
            selectedElement: element,
            panOffset: &panOffset,
            revisionCounter: &revisionCounter
        )

        XCTAssertEqual(element.transform, originalTransform)
    }

    func testMoveToolIncrementsRevisionCounter() {
        let element = SVGRect(x: 0, y: 0, width: 10, height: 10)
        var panOffset = CGSize.zero
        var revisionCounter = 5

        EditorTool.handleDrag(
            tool: .move,
            dragTranslation: CGSize(width: 1, height: 1),
            selectedElement: element,
            panOffset: &panOffset,
            revisionCounter: &revisionCounter
        )

        XCTAssertEqual(revisionCounter, 6)
    }

    func testSelectToolDoesNotIncrementRevisionCounter() {
        let element = SVGRect(x: 0, y: 0, width: 10, height: 10)
        var panOffset = CGSize.zero
        var revisionCounter = 3

        EditorTool.handleDrag(
            tool: .select,
            dragTranslation: CGSize(width: 10, height: 10),
            selectedElement: element,
            panOffset: &panOffset,
            revisionCounter: &revisionCounter
        )

        XCTAssertEqual(revisionCounter, 3)
    }

    // MARK: - Error / Edge Conditions

    func testMoveToolWithNilSelection() {
        var panOffset = CGSize(width: 0, height: 0)
        var revisionCounter = 0

        EditorTool.handleDrag(
            tool: .move,
            dragTranslation: CGSize(width: 42, height: 42),
            selectedElement: nil,
            panOffset: &panOffset,
            revisionCounter: &revisionCounter
        )

        XCTAssertEqual(panOffset.width, 42)
        XCTAssertEqual(panOffset.height, 42)
        XCTAssertEqual(revisionCounter, 0)
    }

    func testAllCasesEnumerated() {
        XCTAssertEqual(EditorTool.allCases, [.select, .move])
    }

    func testIdentifiableConformance() {
        XCTAssertEqual(EditorTool.select.id, "select")
        XCTAssertEqual(EditorTool.move.id, "move")
    }
}
