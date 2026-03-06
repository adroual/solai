import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var preferences: PreferencesStore

    var body: some View {
        Form {
            Toggle("Notifications", isOn: $preferences.notificationsEnabled)

            Toggle("Launch at Login", isOn: Binding(
                get: { preferences.launchAtLogin },
                set: { newValue in
                    let success = LaunchAtLoginHelper.set(enabled: newValue)
                    if success {
                        preferences.launchAtLogin = newValue
                    }
                }
            ))
        }
        .formStyle(.grouped)
        .frame(width: 280, height: 120)
    }
}

enum LaunchAtLoginHelper {
    private static let plistName = "com.solai.launcher"
    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(plistName).plist")
    }

    static func set(enabled: Bool) -> Bool {
        // Try SMAppService first (works in signed .app bundles)
        if Bundle.main.bundleIdentifier != nil {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                return true
            } catch {
                // fall through to LaunchAgent approach
            }
        }

        // Fallback: LaunchAgent plist
        if enabled {
            return installLaunchAgent()
        } else {
            return removeLaunchAgent()
        }
    }

    private static func installLaunchAgent() -> Bool {
        let executablePath = ProcessInfo.processInfo.arguments.first ?? ""
        let plist: [String: Any] = [
            "Label": plistName,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": false
        ]

        let dir = plistURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        do {
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private static func removeLaunchAgent() -> Bool {
        do {
            try FileManager.default.removeItem(at: plistURL)
            return true
        } catch {
            return !FileManager.default.fileExists(atPath: plistURL.path)
        }
    }
}
