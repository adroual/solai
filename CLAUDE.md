# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is Solai

A native macOS menu bar app that monitors Claude Code session status via hook scripts. 12 radiating bars animate differently for each state (sleeping, working, idle, waiting). Communicates via state files in `/tmp/solai_state_{PID}`.

**Stack:** Swift 5.9+ / SwiftUI / AppKit — macOS 14+ (Sonoma)
**Distribution:** Notarized DMG (not App Store — requires unsandboxed filesystem access)
**Repo:** https://github.com/adroual/solai

## Build Commands

```bash
# Debug build (SPM)
swift build
.build/debug/Solai

# Release .app bundle (Developer ID signed)
bash scripts/build-app.sh
open .build/Solai.app

# Install to /Applications
rm -rf /Applications/Solai.app && cp -R .build/Solai.app /Applications/Solai.app

# Notarized DMG (signs, notarizes with Apple, staples ticket)
bash scripts/create-dmg.sh

# Update GitHub release
gh release upload v1.0.0 .build/Solai.dmg --clobber
```

## Architecture

**State flow:** Claude Code hook → inline bash command → `/tmp/solai_state_$PPID` → FSEvents → SessionManager → BarAnimator → BarRenderer → NSStatusItem.image

**Key components:**
- `BarAnimator` — Pure function: `(MonitorState, time) -> [Bar]`. All animation math lives here. No UI dependencies.
- `BarRenderer` — `[Bar] -> NSImage` via Core Graphics. Template image at 22pt with opacity boost for menu bar visibility.
- `StatusBarController` — Owns NSStatusItem, drives animation timer (20-30 FPS depending on state), subscribes to SessionManager via Combine.
- `SessionManager` — Watches `/tmp/` via FSEvents for `solai_state_*` files. Parses state + metadata. Priority aggregation. Cleans up dead PIDs.
- `MenuBuilder` — NSMenuDelegate, rebuilds on every open. Option-key reveals "Uninstall Hooks...". Clicking session activates Ghostty.
- `HookInstaller` — Registers inline commands in `~/.claude/settings.json` per hook event. No external script files. Uses `#solai` comment as marker for identification/cleanup.
- `NotificationManager` — UNUserNotificationCenter with 5s coalescing. Requires .app bundle (disabled in SPM debug).
- `SettingsWindowController` — Small SwiftUI window for Notifications toggle and Launch at Login.

## Hook System

Hooks are **inline bash commands** registered in `~/.claude/settings.json`, not external scripts. Each event gets its own command:
- `SessionStart` → writes "idle" + meta file with project path and PID
- `UserPromptSubmit/PreToolUse/PostToolUse` → writes "working"
- `Notification` → writes "waiting"
- `Stop` → writes "idle"
- `SessionEnd` → **deletes** state and meta files

Session ID is `$PPID` (Claude Code process PID). All commands end with `#solai` comment for identification.

## State File Protocol

State: `/tmp/solai_state_{PID}` — single line: `working`, `idle`, `waiting`, or `sleeping`
Meta: `/tmp/solai_meta_{PID}` — JSON: `{"project": "/path/to/project", "pid": 12345}`
Sessions without a meta file are filtered out (subprocess noise).
Dead PIDs are cleaned up on scan. 30-minute timeout as fallback.

## Signing & Distribution

- Signed with "Developer ID Application: Alexandre Droual (2FHSYNGW44)"
- Notarization credentials stored in Keychain as profile "notarytool"
- `Info.plist` sets `LSUIElement = true` (menu bar only, no dock icon)
- Bundle ID: `com.musicmi.solai`

## Important Notes

- Notifications and SMAppService require a proper .app bundle; they gracefully degrade in SPM debug builds
- Launch at Login falls back to LaunchAgent plist (`~/Library/LaunchAgents/com.solai.launcher.plist`) when SMAppService is unavailable
- Animation values in BarAnimator are tuned for 22pt menu bar rendering with opacity boost in BarRenderer (min 0.4, 1.4x multiplier)
- Ghostty splits can't be individually focused — clicking a session just activates Ghostty
