import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let sessionManager = SessionManager()
    private let notificationManager = NotificationManager()
    private let preferences = PreferencesStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        notificationManager.setup()
        HookInstaller.installIfNeeded()

        statusBarController = StatusBarController(
            sessionManager: sessionManager,
            notificationManager: notificationManager,
            preferences: preferences
        )
        sessionManager.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusBarController?.cleanup()
        sessionManager.stop()
    }
}
