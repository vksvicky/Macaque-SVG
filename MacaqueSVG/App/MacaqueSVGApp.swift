import SwiftUI

@main
struct MacaqueSVGApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: SVGFileDocument()) { configuration in
            DocumentEditorView(document: configuration.$document, documentURL: configuration.fileURL)
        }
    }
}
