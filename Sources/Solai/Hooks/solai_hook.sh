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
