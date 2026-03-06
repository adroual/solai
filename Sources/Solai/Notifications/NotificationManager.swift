import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private var previousStates: [String: MonitorState] = [:]
    private var lastNotificationTime: [String: Date] = [:]
    private let coalescingInterval: TimeInterval = 5 // seconds between duplicate notifications

    private var isAvailable = false

    func setup() {
        // UNUserNotificationCenter requires a valid bundle identifier
        guard Bundle.main.bundleIdentifier != nil else {
            isAvailable = false
            return
        }
        isAvailable = true
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func processStateChanges(sessions: [Session], notificationsEnabled: Bool) {
        guard isAvailable, notificationsEnabled else {
            updatePreviousStates(sessions)
            return
        }

        let now = Date()

        for session in sessions {
            let oldState = previousStates[session.id]
            let newState = session.state

            guard let oldState = oldState, oldState != newState else { continue }

            // Coalesce: skip if we just notified for this session
            if let lastTime = lastNotificationTime[session.id],
               now.timeIntervalSince(lastTime) < coalescingInterval { continue }

            let projectName = session.projectName ?? session.id

            switch newState {
            case .waiting:
                send(
                    title: "Claude Code needs you",
                    body: projectName,
                    identifier: "waiting-\(session.id)",
                    sound: .default
                )
                lastNotificationTime[session.id] = now

            case .idle where oldState == .working:
                send(
                    title: "Task complete",
                    body: projectName,
                    identifier: "idle-\(session.id)",
                    sound: UNNotificationSound(named: UNNotificationSoundName("Boop"))
                )
                lastNotificationTime[session.id] = now

            default:
                break
            }
        }

        updatePreviousStates(sessions)
    }

    private func updatePreviousStates(_ sessions: [Session]) {
        // Clean up states for sessions that no longer exist
        let currentIDs = Set(sessions.map(\.id))
        previousStates = previousStates.filter { currentIDs.contains($0.key) }
        lastNotificationTime = lastNotificationTime.filter { currentIDs.contains($0.key) }

        for session in sessions {
            previousStates[session.id] = session.state
        }
    }

    private func send(title: String, body: String, identifier: String, sound: UNNotificationSound?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
