import AppKit
import SwiftUI

final class AboutWindowController {
    private var window: NSWindow?

    func show() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let hostingController = NSHostingController(rootView: AboutView())

        let window = NSWindow(contentViewController: hostingController)
        window.title = "About Solai"
        window.styleMask = [.titled, .closable]
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()

        self.window = window
    }
}
