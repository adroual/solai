import Foundation

struct HookInstaller {
    private static let hookFileName = "solai_hook.sh"
    private static let hookInstallDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/hooks")
    private static let settingsPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/settings.json")

    static func installIfNeeded() {
        let fm = FileManager.default

        // Create hooks directory
        try? fm.createDirectory(at: hookInstallDir, withIntermediateDirectories: true)

        let installedHookPath = hookInstallDir.appendingPathComponent(hookFileName)

        // Copy hook script from bundle or resource bundle
        let bundledHook: URL
        if let bundleURL = Bundle.main.url(forResource: "solai_hook", withExtension: "sh") {
            bundledHook = bundleURL
        } else if let resourceBundle = Bundle.module.url(forResource: "solai_hook", withExtension: "sh") {
            bundledHook = resourceBundle
        } else {
            // Write the script content directly as fallback
            writeHookScript(to: installedHookPath)
            updateSettings()
            return
        }

        // Always update to latest version
        try? fm.removeItem(at: installedHookPath)
        try? fm.copyItem(at: bundledHook, to: installedHookPath)

        // Make executable
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: installedHookPath.path)

        // Update settings.json to register hooks
        updateSettings()
    }

    private static func updateSettings() {
        let fm = FileManager.default
        let hookCommand = "bash ~/.claude/hooks/\(hookFileName)"

        var settings: [String: Any] = [:]

        // Read existing settings
        if fm.fileExists(atPath: settingsPath.path),
           let data = try? Data(contentsOf: settingsPath),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = existing
        }

        // Get or create hooks dictionary
        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        let solaiHookEntry: [String: Any] = [
            "type": "command",
            "command": hookCommand
        ]

        let hookEvents = [
            "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse",
            "Stop", "SessionEnd", "Notification"
        ]

        for event in hookEvents {
            var eventHooks = hooks[event] as? [[String: Any]] ?? []

            // Check if solai hook already registered
            let alreadyInstalled = eventHooks.contains { entry in
                let entryHooks = entry["hooks"] as? [[String: Any]] ?? []
                return entryHooks.contains { ($0["command"] as? String)?.contains("solai_hook") == true }
            }

            if !alreadyInstalled {
                eventHooks.append(["hooks": [solaiHookEntry]])
                hooks[event] = eventHooks
            }
        }

        settings["hooks"] = hooks

        // Preserve schema
        if settings["$schema"] == nil {
            settings["$schema"] = "https://json.schemastore.org/claude-code-settings.json"
        }

        // Write back
        if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: settingsPath, options: .atomic)
        }
    }

    private static func writeHookScript(to url: URL) {
        let script = """
        #!/bin/bash
        STATE_FILE="/tmp/solai_state_${CLAUDE_SESSION_ID:-default}"
        META_FILE="/tmp/solai_meta_${CLAUDE_SESSION_ID:-default}"
        EVENT="${CLAUDE_HOOK_EVENT:-unknown}"

        case "$EVENT" in
          SessionStart)
            echo "working" > "$STATE_FILE"
            echo "{\\"project\\":\\"$(pwd)\\",\\"pid\\":$$}" > "$META_FILE"
            ;;
          UserPromptSubmit|PreToolUse|PostToolUse)
            echo "working" > "$STATE_FILE" ;;
          PermissionRequest|Notification)
            echo "waiting" > "$STATE_FILE" ;;
          Stop|SessionEnd)
            echo "idle" > "$STATE_FILE" ;;
        esac
        exit 0
        """
        try? script.write(to: url, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    static func uninstall() {
        let fm = FileManager.default
        let installedHookPath = hookInstallDir.appendingPathComponent(hookFileName)

        // Remove hook script
        try? fm.removeItem(at: installedHookPath)

        // Remove hooks from settings.json
        guard fm.fileExists(atPath: settingsPath.path),
              let data = try? Data(contentsOf: settingsPath),
              var settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = settings["hooks"] as? [String: Any] else { return }

        for (event, value) in hooks {
            guard var eventHooks = value as? [[String: Any]] else { continue }
            eventHooks.removeAll { entry in
                let entryHooks = entry["hooks"] as? [[String: Any]] ?? []
                return entryHooks.contains { ($0["command"] as? String)?.contains("solai_hook") == true }
            }
            hooks[event] = eventHooks.isEmpty ? nil : eventHooks
        }

        settings["hooks"] = hooks

        if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: settingsPath, options: .atomic)
        }
    }
}
