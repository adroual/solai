import Foundation

final class PreferencesStore: ObservableObject {
    private enum Keys {
        static let notificationsEnabled = "notificationsEnabled"
        static let launchAtLogin = "launchAtLogin"
    }

    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            Keys.notificationsEnabled: true,
            Keys.launchAtLogin: false
        ])
        self.notificationsEnabled = defaults.bool(forKey: Keys.notificationsEnabled)
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
    }
}
