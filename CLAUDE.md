# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is Solai

A native macOS menu bar app that monitors Claude Code session status via hook scripts. 12 radiating bars animate differently for each state (sleeping, working, idle, waiting). Communicates via state files in `/tmp/solai_state_{SESSION_ID}`.

## Build Commands

```bash
# Debug build (SPM)
swift build

# Run debug build
.build/debug/Solai

# Build .app bundle (release, ad-hoc signed)
bash scripts/build-app.sh
open .build/Solai.app

# Create DMG for distribution
bash scripts/create-dmg.sh
```

## Architecture

**State flow:** Claude Code hook event -> `solai_hook.sh` -> `/tmp/solai_state_*` file -> FSEvents watcher -> SessionManager -> BarAnimator -> BarRenderer -> NSStatusItem.image

**Key components:**
- `BarAnimator` — Pure function: `(MonitorState, time) -> [Bar]`. All animation math lives here. No UI dependencies.
- `BarRenderer` — `[Bar] -> NSImage` via Core Graphics. Template image at 22pt, auto-scales for retina.
- `StatusBarController` — Owns NSStatusItem, drives animation timer (20-30 FPS depending on state), subscribes to SessionManager via Combine.
- `SessionManager` — Watches `/tmp/` via FSEvents for `solai_state_*` files. Parses state + metadata. Priority aggregation across sessions.
- `MenuBuilder` — NSMenuDelegate, rebuilds on every open. Option-key reveals "Uninstall Hooks...".
- `HookInstaller` — Copies hook script to `~/.claude/hooks/`, registers in `~/.claude/settings.json`.
- `NotificationManager` — UNUserNotificationCenter with 5s coalescing. Requires .app bundle (disabled in SPM debug).

## State File Protocol

State: `/tmp/solai_state_{SESSION_ID}` — single line: `working`, `idle`, `waiting`, or `sleeping`
Meta: `/tmp/solai_meta_{SESSION_ID}` — JSON: `{"project": "...", "pid": 123}`
Timeout: 30 minutes since last mtime.

## Important Notes

- `LSUIElement = true` in Info.plist — menu bar only, no dock icon
- Notifications and SMAppService require a proper .app bundle with bundle identifier; they gracefully degrade in SPM debug builds
- Launch at Login falls back to LaunchAgent plist when SMAppService is unavailable
- Animation values in BarAnimator are tuned for 22pt menu bar rendering with opacity boost in BarRenderer
