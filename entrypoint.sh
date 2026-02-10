#!/bin/bash
set -e

# Configuration from environment
TTYD_PORT="${TTYD_PORT:-7681}"
WORKSPACE="${WORKSPACE:-/home/claude/workspace}"
SESSION_NAME="${SESSION_NAME:-claude}"

# Start a tmux session with Claude Code if one doesn't exist
if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux new-session -d -s "$SESSION_NAME" -c "$WORKSPACE" \
        "claude --dangerously-skip-permissions; exec bash"
fi

# Build keyboard bar (extracts ttyd HTML + injects keyboard on first boot)
CUSTOM_INDEX="/home/claude/.ttyd-keyboard.html"
KEYBOARD_SETUP="/home/claude/setup-keyboard.sh"
if [ -f "$KEYBOARD_SETUP" ]; then
    bash "$KEYBOARD_SETUP" || true
fi

# Build ttyd args
TTYD_ARGS=(-W -p "$TTYD_PORT" -t titleFixed="Claude Code" -t fontSize=14)

# Use custom index with keyboard bar if available
if [ -f "$CUSTOM_INDEX" ]; then
    TTYD_ARGS+=(--index "$CUSTOM_INDEX")
fi

# Optional basic auth (off by default — Tailscale handles access)
if [ -n "$TTYD_USER" ] && [ -n "$TTYD_PASS" ]; then
    TTYD_ARGS+=(-c "${TTYD_USER}:${TTYD_PASS}")
fi

exec ttyd "${TTYD_ARGS[@]}" tmux attach-session -t "$SESSION_NAME"
