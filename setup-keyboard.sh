#!/bin/bash
# Extracts ttyd's default HTML and injects:
#   1. ws-proxy.html   — right after <head> (WebSocket interception, before ttyd scripts)
#   2. keyboard-bar.html — before </body> (UI bar that uses the intercepted socket)
# Called once at first boot; cached for subsequent starts.
set -e

CACHED_HTML="/home/claude/.ttyd-keyboard.html"
KEYBOARD_SNIPPET="${KEYBOARD_SNIPPET:-/home/claude/keyboard-bar.html}"
WS_PROXY_SNIPPET="${WS_PROXY_SNIPPET:-/home/claude/ws-proxy.html}"

# Skip if already built and neither snippet has changed
if [ -f "$CACHED_HTML" ] \
   && [ "$CACHED_HTML" -nt "$KEYBOARD_SNIPPET" ] \
   && [ "$CACHED_HTML" -nt "$WS_PROXY_SNIPPET" ]; then
    echo "[keyboard] Using cached ttyd+keyboard HTML"
    exit 0
fi

echo "[keyboard] Building custom ttyd index with keyboard bar..."

# Start ttyd briefly on a temp port to capture its default HTML
TEMP_PORT=17681
ttyd -p $TEMP_PORT bash -c "sleep 10" &
TEMP_PID=$!

# Wait for ttyd to be ready
for i in $(seq 1 20); do
    if curl -s -o /dev/null http://localhost:$TEMP_PORT/ 2>/dev/null; then
        break
    fi
    sleep 0.25
done

# Capture the original HTML
if ! curl -s http://localhost:$TEMP_PORT/ > /tmp/ttyd-original.html 2>/dev/null; then
    echo "[keyboard] WARN: Could not capture ttyd HTML, skipping keyboard bar"
    kill $TEMP_PID 2>/dev/null; wait $TEMP_PID 2>/dev/null
    exit 0
fi

kill $TEMP_PID 2>/dev/null
wait $TEMP_PID 2>/dev/null || true

# Verify we got valid HTML
if ! grep -q '<!DOCTYPE html>' /tmp/ttyd-original.html; then
    echo "[keyboard] WARN: Invalid HTML captured, skipping keyboard bar"
    exit 0
fi

# Two-phase injection using python3:
# 1. ws-proxy.html after <head> (so it runs before ttyd's bundled JS)
# 2. keyboard-bar.html before </body> (UI that reads window.__ttyd_sock)
python3 - "$WS_PROXY_SNIPPET" "$KEYBOARD_SNIPPET" /tmp/ttyd-original.html "$CACHED_HTML" << 'PYEOF'
import sys

ws_proxy_path, kb_path, original_path, output_path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

with open(original_path, 'r') as f:
    html = f.read()
with open(ws_proxy_path, 'r') as f:
    ws_proxy = f.read()
with open(kb_path, 'r') as f:
    keyboard = f.read()

# Phase 1: inject ws-proxy right after <head>
html = html.replace('<head>', '<head>\n' + ws_proxy, 1)

# Phase 2: inject keyboard bar before </body>
html = html.replace('</body>', keyboard + '\n</body>', 1)

with open(output_path, 'w') as f:
    f.write(html)
print('[keyboard] Custom ttyd index built successfully (ws-proxy + keyboard bar)')
PYEOF
