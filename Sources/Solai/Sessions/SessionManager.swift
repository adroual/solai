import Foundation

final class SessionManager: ObservableObject {
    @Published private(set) var sessions: [Session] = []
    @Published private(set) var aggregateState: MonitorState = .sleeping

    private var fileWatcher: FileWatcher?
    private var cleanupTimer: Timer?
    private let statePrefix = "solai_state_"
    private let metaPrefix = "solai_meta_"
    private let tmpDir = "/tmp"
    private let timeoutInterval: TimeInterval = 30 * 60 // 30 minutes

    func start() {
        scan()

        // FSEvents watcher on /tmp for instant notification
        fileWatcher = FileWatcher(path: tmpDir) { [weak self] in
            self?.scan()
        }
        fileWatcher?.start()

        // Periodic cleanup of timed-out sessions (every 60s)
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.scan()
        }
    }

    func stop() {
        fileWatcher?.stop()
        fileWatcher = nil
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }

    func scan() {
        let fm = FileManager.default
        let now = Date()

        guard let files = try? fm.contentsOfDirectory(atPath: tmpDir) else { return }

        let stateFiles = files.filter { $0.hasPrefix(statePrefix) }

        var newSessions: [Session] = []

        for file in stateFiles {
            let sessionID = String(file.dropFirst(statePrefix.count))
            let statePath = "\(tmpDir)/\(file)"

            guard let attrs = try? fm.attributesOfItem(atPath: statePath),
                  let mtime = attrs[.modificationDate] as? Date else { continue }

            // Timeout: remove stale state files
            if now.timeIntervalSince(mtime) > timeoutInterval {
                try? fm.removeItem(atPath: statePath)
                try? fm.removeItem(atPath: "\(tmpDir)/\(metaPrefix)\(sessionID)")
                continue
            }

            guard let content = try? String(contentsOfFile: statePath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
                  let state = MonitorState(rawValue: content) else { continue }

            var projectName: String?
            var projectPath: String?
            var pid: Int?

            let metaPath = "\(tmpDir)/\(metaPrefix)\(sessionID)"
            if let metaData = try? Data(contentsOf: URL(fileURLWithPath: metaPath)),
               let meta = try? JSONSerialization.jsonObject(with: metaData) as? [String: Any] {
                projectPath = meta["project"] as? String
                projectName = projectPath.map { URL(fileURLWithPath: $0).lastPathComponent }
                pid = meta["pid"] as? Int
            } else {
                // No meta file — likely a subprocess, not a real session. Skip it.
                continue
            }

            newSessions.append(Session(
                id: sessionID,
                state: state,
                projectName: projectName,
                projectPath: projectPath,
                pid: pid,
                lastUpdate: mtime
            ))
        }

        sessions = newSessions.sorted { $0.state.priority > $1.state.priority }
        aggregateState = sessions.map(\.state).max(by: { $0.priority < $1.priority }) ?? .sleeping
    }

    deinit {
        stop()
    }
}
