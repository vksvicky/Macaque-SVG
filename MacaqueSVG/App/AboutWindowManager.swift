import AppKit
import SwiftUI

@MainActor
final class AboutWindowManager: NSObject, NSWindowDelegate {
    static let shared = AboutWindowManager()
    private var aboutWindow: NSWindow?

    override private init() {
        super.init()
    }

    func showAboutWindow() {
        if let window = aboutWindow, window.isReleasedWhenClosed == false {
            NotificationCenter.default.post(name: .refreshAboutWindow, object: nil)
            window.makeKeyAndOrderFront(nil)
            return
        }

        aboutWindow = nil

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Macaque SVG"
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        let hostingView = NSHostingView(rootView: AboutView())
        window.contentView = hostingView

        aboutWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        aboutWindow = nil
    }
}

extension Notification.Name {
    static let refreshAboutWindow = Notification.Name("refreshAboutWindow")
}
