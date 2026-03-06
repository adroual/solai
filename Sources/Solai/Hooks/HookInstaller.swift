import Foundation

struct HookInstaller {
    private static let settingsPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/settings.json")

    private static let solaiMarker = "#solai#"

    // Each event maps to the state it should write
    private static let eventStateMap: [(event: String, state: String)] = [
        ("SessionStart", "idle"),
        ("UserPromptSubmit", "working"),
        ("PreToolUse", "working"),
        ("PostToolUse", "working"),
        ("Notification", "waiting"),
        ("Stop", "idle"),
        ("SessionEnd", "idle"),
    ]

    static func installIfNeeded() {
        updateSettings()
    }

    private static func updateSettings() {
        let fm = FileManager.default

        var settings: [String: Any] = [:]

        if fm.fileExists(atPath: settingsPath.path),
           let data = try? Data(contentsOf: settingsPath),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = existing
        }

        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        for (event, state) in eventStateMap {
            var eventHooks = hooks[event] as? [[String: Any]] ?? []

            // Check if solai hook already registered
            let alreadyInstalled = eventHooks.contains { entry in
                let entryHooks = entry["hooks"] as? [[String: Any]] ?? []
                return entryHooks.contains { ($0["command"] as? String)?.contains("#solai") == true }
            }

            if !alreadyInstalled {
                let command = commandFor(event: event, state: state)
                let hookEntry: [String: Any] = [
                    "type": "command",
                    "command": command
                ]
                eventHooks.append(["hooks": [hookEntry]])
                hooks[event] = eventHooks
            }
        }

        settings["hooks"] = hooks

        if settings["$schema"] == nil {
            settings["$schema"] = "https://json.schemastore.org/claude-code-settings.json"
        }

        if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: settingsPath, options: .atomic)
        }
    }

    private static func commandFor(event: String, state: String) -> String {
        // Prefix with "solai:" marker for identification
        // Use $PPID as a stable session identifier (Claude Code process PID)
        if event == "SessionStart" {
            return "echo \(state) > /tmp/solai_state_$PPID; printf '{\"project\":\"%s\",\"pid\":%d}' \"$(pwd)\" $PPID > /tmp/solai_meta_$PPID #solai"
        }
        if event == "SessionEnd" {
            return "rm -f /tmp/solai_state_$PPID /tmp/solai_meta_$PPID #solai"
        }
        return "echo \(state) > /tmp/solai_state_$PPID #solai"
    }

    static func uninstall() {
        let fm = FileManager.default

        guard fm.fileExists(atPath: settingsPath.path),
              let data = try? Data(contentsOf: settingsPath),
              var settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = settings["hooks"] as? [String: Any] else { return }

        for (event, value) in hooks {
            guard var eventHooks = value as? [[String: Any]] else { continue }
            eventHooks.removeAll { entry in
                let entryHooks = entry["hooks"] as? [[String: Any]] ?? []
                return entryHooks.contains { ($0["command"] as? String)?.contains("#solai") == true }
            }
            hooks[event] = eventHooks.isEmpty ? nil : eventHooks
        }

        settings["hooks"] = hooks

        if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: settingsPath, options: .atomic)
        }

        // Clean up old hook script if it exists
        let oldHookPath = fm.homeDirectoryForCurrentUser.appendingPathComponent(".claude/hooks/solai_hook.sh")
        try? fm.removeItem(at: oldHookPath)
    }
}
