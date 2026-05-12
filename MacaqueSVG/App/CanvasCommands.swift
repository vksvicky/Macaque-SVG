import SwiftUI

extension Notification.Name {
    static let resetCanvasViewport = Notification.Name("resetCanvasViewport")
    static let canvasZoomIn = Notification.Name("canvasZoomIn")
    static let canvasZoomOut = Notification.Name("canvasZoomOut")
}

@MainActor
final class CanvasActions: ObservableObject {
    @Binding var useCanvasMode: Bool
    @Binding var selectedElement: SVGElement?

    init(useCanvasMode: Binding<Bool>, selectedElement: Binding<SVGElement?>) {
        _useCanvasMode = useCanvasMode
        _selectedElement = selectedElement
    }

    func resetViewport() {
        NotificationCenter.default.post(name: .resetCanvasViewport, object: nil)
    }
}

private struct CanvasActionsKey: FocusedValueKey {
    typealias Value = CanvasActions
}

extension FocusedValues {
    var canvasActions: CanvasActions? {
        get { self[CanvasActionsKey.self] }
        set { self[CanvasActionsKey.self] = newValue }
    }
}

struct CanvasCommands: Commands {
    @FocusedValue(\.canvasActions) var actions

    var body: some Commands {
        CommandMenu("Canvas") {
            Button(actions?.useCanvasMode == true ? "Switch to Preview Mode" : "Switch to Edit Mode") {
                actions?.useCanvasMode.toggle()
            }
            .keyboardShortcut("e", modifiers: .command)

            Divider()

            Button("Deselect All") {
                actions?.selectedElement = nil
            }
            .keyboardShortcut(.escape, modifiers: [])
            .disabled(actions?.selectedElement == nil)

            Divider()

            Button("Zoom In") {
                NotificationCenter.default.post(name: .canvasZoomIn, object: nil)
            }
            .keyboardShortcut("=", modifiers: .command)

            Button("Zoom Out") {
                NotificationCenter.default.post(name: .canvasZoomOut, object: nil)
            }
            .keyboardShortcut("-", modifiers: .command)

            Button("Reset Zoom & Pan") {
                actions?.resetViewport()
            }
            .keyboardShortcut("0", modifiers: .command)
        }
    }
}
