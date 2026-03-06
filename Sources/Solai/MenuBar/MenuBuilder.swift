import AppKit

final class MenuBuilder: NSObject, NSMenuDelegate {
    private let sessionManager: SessionManager
    private let settingsWindowController: SettingsWindowController
    private let aboutWindowController = AboutWindowController()

    init(sessionManager: SessionManager, preferences: PreferencesStore) {
        self.sessionManager = sessionManager
        self.settingsWindowController = SettingsWindowController(preferences: preferences)
    }

    func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        populateMenu(menu)
        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        populateMenu(menu)
    }

    private func populateMenu(_ menu: NSMenu) {
        let sessions = sessionManager.sessions

        if sessions.isEmpty {
            let noSession = NSMenuItem(title: "No active Claude Code session", action: nil, keyEquivalent: "")
            noSession.isEnabled = false
            menu.addItem(noSession)
        } else if sessions.count == 1, let session = sessions.first {
            menu.addItem(menuItem(for: session))
        } else {
            let header = NSMenuItem(title: "Sessions", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for session in sessions {
                menu.addItem(menuItem(for: session))
            }
        }

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: "About Solai", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        // Option-key: reveal uninstall
        let optionDown = NSEvent.modifierFlags.contains(.option)
        if optionDown {
            let uninstallItem = NSMenuItem(title: "Uninstall Hooks...", action: #selector(uninstallHooks), keyEquivalent: "")
            uninstallItem.target = self
            menu.addItem(uninstallItem)
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Solai", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func menuItem(for session: Session) -> NSMenuItem {
        let name = session.projectName ?? session.id
        let stateLabel = stateDisplay(session.state)
        let title = "\(name) — \(stateLabel)"
        let item = NSMenuItem(title: title, action: #selector(sessionClicked(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = session
        return item
    }

    @objc private func sessionClicked(_ sender: NSMenuItem) {
        guard let session = sender.representedObject as? Session else { return }
        focusGhosttyWindow(for: session)
    }

    @objc private func openSettings() {
        settingsWindowController.showSettings()
    }

    @objc private func openAbout() {
        aboutWindowController.show()
    }

    @objc private func uninstallHooks() {
        let alert = NSAlert()
        alert.messageText = "Uninstall Solai Hooks?"
        alert.informativeText = "This will remove the Solai hook script and its entries from Claude Code settings."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            HookInstaller.uninstall()
        }
    }

    private func focusGhosttyWindow(for session: Session) {
        if let ghosttyURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.mitchellh.ghostty") {
            NSWorkspace.shared.openApplication(at: ghosttyURL, configuration: .init())
        }
    }

    private func stateDisplay(_ state: MonitorState) -> String {
        switch state {
        case .working:  return "Working"
        case .idle:     return "Idle"
        case .waiting:  return "Waiting"
        case .sleeping: return "Sleeping"
        }
    }
}
