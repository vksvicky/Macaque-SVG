import CoreGraphics
import Foundation

enum EditorTool: String, CaseIterable, Identifiable {
    case select
    case move

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .select: "Select"
        case .move: "Move"
        }
    }

    var systemImage: String {
        switch self {
        case .select: "cursorarrow"
        case .move: "arrow.up.and.down.and.arrow.left.and.right"
        }
    }

    var shortcutKey: Character {
        switch self {
        case .select: "v"
        case .move: "m"
        }
    }

    /// Applies a drag translation according to the active tool.
    ///
    /// - `.select` always pans the canvas.
    /// - `.move` translates the selected element when one exists;
    ///   otherwise falls through to panning.
    static func handleDrag(
        tool: EditorTool,
        dragTranslation: CGSize,
        selectedElement: SVGElement?,
        panOffset: inout CGSize,
        revisionCounter: inout Int
    ) {
        switch tool {
        case .select:
            panOffset.width += dragTranslation.width
            panOffset.height += dragTranslation.height

        case .move:
            if let element = selectedElement {
                element.transform.tx += dragTranslation.width
                element.transform.ty += dragTranslation.height
                revisionCounter += 1
            } else {
                panOffset.width += dragTranslation.width
                panOffset.height += dragTranslation.height
            }
        }
    }
}
