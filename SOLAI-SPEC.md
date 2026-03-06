# Solai — Build Spec v1.0

> A native macOS menu bar app to track Claude Code session status with animated visual feedback and native notifications.

**Stack:** Swift 5.9+ / SwiftUI / AppKit  
**Target:** macOS 14+ (Sonoma)  
**License:** MIT  

---

## 1. What It Does

A menu bar icon made of **12 radiating bars** arranged in a circle (no center element). Each Claude Code state produces a distinct animation pattern. The icon is a monochromatic template image — macOS auto-adapts for light/dark.

### States

| State | Hook Trigger | Animation | Speed |
|-------|-------------|-----------|-------|
| sleeping | SessionEnd / 30min timeout | Slow breathing sine. Short bars, low opacity (0.15–0.35). | 0.4× |
| working | UserPromptSubmit / ToolUse | Rotating energy wave. Bars near peak extend long. | 1.2× |
| idle | Stop | All bars uniform. Synchronized pulse + per-bar shimmer. | 0.5× |
| waiting | PermissionRequest | Alternating ripple burst. Even/odd bars on offset phases. | 0.8× |

---

## 2. Animation Math

All bars share: `angle = (i / 12) × 2π` where `i ∈ [0..11]`.

Each bar has 5 properties: `angle`, `innerR`, `outerR`, `opacity`, `thickness` (all 0–1 as fraction of icon radius).

### Sleeping
```
phase = t × 2π × 0.4
breathe = sin(phase + i × 0.15) × 0.5 + 0.5
innerR = 0.22 + breathe × 0.04
outerR = 0.36 + breathe × 0.12
opacity = 0.15 + breathe × 0.2
thickness = 0.08
```

### Working
```
phase = t × 2π × 1.2
wave = sin(angle - phase) × 0.5 + 0.5
wave2 = sin(angle - phase × 0.7 + 1.5) × 0.3 + 0.3
innerR = 0.18 - wave × 0.04
outerR = 0.38 + wave × 0.35 + wave2 × 0.12
opacity = 0.2 + wave × 0.55
thickness = 0.075 + wave × 0.02
```

### Idle
```
phase = t × 2π × 0.5
pulse = sin(phase) × 0.5 + 0.5
shimmer = sin(phase × 2.5 + i × 0.8) × 0.08
innerR = 0.2
outerR = 0.48 + pulse × 0.1 + shimmer
opacity = 0.35 + pulse × 0.15 + shimmer
thickness = 0.08
```

### Waiting
```
phase = t × 2π × 0.8
ripple1 = sin(phase × 2) × 0.5 + 0.5
ripple2 = sin(phase × 2.5 + π) × 0.5 + 0.5
r = (i % 2 == 0) ? ripple1 : ripple2
innerR = 0.15 + (1 - r) × 0.1
outerR = 0.3 + r × 0.45
opacity = 0.2 + r × 0.55
thickness = 0.08 + r × 0.02
```

### Rendering
- Canvas: 32×32pt (64×64px @2x retina)
- Core Graphics paths with `.round` line caps
- All bars drawn in black with varying alpha → `NSImage.isTemplate = true`
- FPS: 30 for working/waiting, 20 for sleeping/idle

---

## 3. Architecture

### State Flow
```
Claude Code event → Hook script (bash) → State file (/tmp) → FSEvents watcher → SessionManager → BarAnimator → BarRenderer → NSStatusItem.image
```

### Components

| Component | Responsibility |
|-----------|---------------|
| StatusBarController | Owns NSStatusItem. Drives animation timer. Updates icon. Builds menu. |
| BarAnimator | Pure function: (state, time) → [Bar]. No UI deps. |
| BarRenderer | [Bar] → CGImage as template. Handles @2x. |
| SessionManager | Tracks active sessions. Reads state files. FSEvents. |
| HookBridge | Installs hooks. Manages hook script. |
| NotificationManager | macOS notifications on state transitions. |
| PreferencesStore | UserDefaults: notifications on/off, launch at login. |

---

## 4. State File Protocol

### Location
```
/tmp/solai_state_{SESSION_ID}
```

### Content
Single line: `working`, `idle`, `waiting`, or `sleeping`. File `mtime` = heartbeat.

### Session metadata (optional)
```
/tmp/solai_meta_{SESSION_ID}
```
```json
{ "project": "/Users/alex/Dev/crewify", "pid": 12345, "started": "2026-03-06T10:00:00Z" }
```

### Timeout
State file mtime > 30 minutes → session considered dead, removed.

### Hook Script (`~/.claude/hooks/solai_hook.sh`)
```bash
#!/bin/bash
STATE_FILE="/tmp/solai_state_${CLAUDE_SESSION_ID:-default}"
META_FILE="/tmp/solai_meta_${CLAUDE_SESSION_ID:-default}"
EVENT="${CLAUDE_HOOK_EVENT:-unknown}"

case "$EVENT" in
  SessionStart)
    echo "working" > "$STATE_FILE"
    echo "{\"project\":\"$(pwd)\",\"pid\":$$}" > "$META_FILE"
    ;;
  UserPromptSubmit|PreToolUse|PostToolUse)
    echo "working" > "$STATE_FILE" ;;
  PermissionRequest|Notification)
    echo "waiting" > "$STATE_FILE" ;;
  Stop|SessionEnd)
    echo "idle" > "$STATE_FILE" ;;
esac
exit 0
```

---

## 5. Multi-Session Logic

SessionManager watches `/tmp/` for `solai_state_*` files. Priority for aggregate icon:

```
waiting (3) > working (2) > idle (1) > sleeping (0)
```

Dropdown lists each session individually with project name + state.

---

## 6. Menu Structure

```
┌───────────────────────────────┐
│  Sessions                     │
│  ● crewify — Working ⚡       │
│  ○ pmm-kit — Idle ✅          │
│  ○ dentanorme — Waiting 👋    │
│───────────────────────────────│
│  🔔 Notifications: ON         │
│───────────────────────────────│
│  Launch at Login              │
│  About                        │
│  Quit                         │
│───────────────────────────────│
```

Single session: replace list with one status line.
No sessions: "No active Claude Code session" (dimmed), icon shows sleeping.

---

## 7. Notifications

| Transition | Notification | Sound |
|-----------|-------------|-------|
| Any → waiting | "👋 Claude Code needs you" + project | Default |
| working → idle | "✅ Task complete" + project | Subtle |
| Any → working | None | — |
| Any → sleeping | None | — |

Uses `UNUserNotificationCenter`. Coalesced (no duplicates).

---

## 8. Project Structure

```
Solai/
├── App/
│   ├── SolaiApp.swift
│   └── AppDelegate.swift
├── MenuBar/
│   ├── StatusBarController.swift
│   └── MenuBuilder.swift
├── Animation/
│   ├── Bar.swift
│   ├── BarAnimator.swift
│   └── BarRenderer.swift
├── Sessions/
│   ├── SessionManager.swift
│   ├── Session.swift
│   └── FileWatcher.swift
├── Hooks/
│   ├── HookInstaller.swift
│   └── solai_hook.sh
├── Notifications/
│   └── NotificationManager.swift
├── Preferences/
│   ├── PreferencesStore.swift
│   └── SettingsView.swift
└── Resources/
    └── Assets.xcassets
```

---

## 9. Key Swift Types

```swift
struct Bar {
    let angle: CGFloat      // radians
    let innerR: CGFloat     // 0...1
    let outerR: CGFloat     // 0...1
    let opacity: CGFloat    // 0...1
    let thickness: CGFloat  // 0...1
}

enum MonitorState: String, Codable {
    case sleeping, working, idle, waiting
    
    var priority: Int {
        switch self {
        case .waiting: return 3
        case .working: return 2
        case .idle:    return 1
        case .sleeping: return 0
        }
    }
}

struct Session: Identifiable {
    let id: String
    var state: MonitorState
    var projectName: String?
    var projectPath: String?
    var pid: Int?
    var lastUpdate: Date
}

// Pure function — no side effects
struct BarAnimator {
    static func bars(for state: MonitorState, at time: CGFloat) -> [Bar]
}

// Renders to template NSImage
struct BarRenderer {
    static func render(bars: [Bar], size: CGFloat, scale: CGFloat) -> NSImage
}
```

---

## 10. Build Phases

### Phase 1 — Core (1 week)
- [ ] Xcode project: macOS App, menu bar only, no dock icon
- [ ] Bar, BarAnimator, BarRenderer implementation
- [ ] StatusBarController with animation timer
- [ ] Single state file watcher (`/tmp/solai_state`)
- [ ] Basic dropdown: status + notifications toggle + quit
- [ ] Hook script bundled, manual install

### Phase 2 — Multi-Session (1 week)
- [ ] SessionManager with FSEvents on `/tmp/`
- [ ] State priority aggregation
- [ ] Session metadata parsing (project name, pid)
- [ ] Dropdown per-session list
- [ ] Session timeout cleanup (30min)

### Phase 3 — Notifications + Install (3–4 days)
- [ ] UNUserNotificationCenter integration
- [ ] Notification coalescing
- [ ] First-launch hook installer (auto settings.json)
- [ ] Launch-at-login via SMAppService

### Phase 4 — Polish + Distribution (3–4 days)
- [ ] About window
- [ ] Uninstall hooks (Option-key reveal)
- [ ] DMG packaging
- [ ] README + screenshots
- [ ] GitHub repo

---

## 11. Technical Decisions

- **FSEvents over polling:** v3 polls every 500ms. Swift uses DispatchSource.makeFileSystemObjectSource for instant notification. Zero CPU waste.
- **NSStatusItem over SwiftUI MenuBarExtra:** Full control over animated icon + custom NSMenu.
- **Template images:** Apple HIG-recommended. Auto light/dark. One asset.
- **Performance targets:** <10MB RAM, <0.2% CPU animating, <0.01% sleeping, <200ms startup, <5MB binary.

---

## 12. Future (Not v1)

- Click-to-focus: clicking session switches Terminal window
- Custom animations: settings pane for speed/bar count/presets
- Homebrew cask distribution
- Session history (SQLite, local only)
- Sparkle auto-updates
- Custom sounds for transitions
