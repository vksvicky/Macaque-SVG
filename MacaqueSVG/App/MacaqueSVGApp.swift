import SwiftUI

@main
struct MacaqueSVGApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        DocumentGroup(newDocument: SVGFileDocument()) { configuration in
            DocumentEditorView(document: configuration.$document, documentURL: configuration.fileURL)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Macaque SVG") {
                    AboutWindowManager.shared.showAboutWindow()
                }
            }
            ExportCommands()
            CanvasCommands()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {}
}
