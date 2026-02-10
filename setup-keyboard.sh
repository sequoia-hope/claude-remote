#!/bin/bash
# Extracts ttyd's default HTML and injects the keyboard bar.
# Called once at first boot; cached for subsequent starts.
set -e

CACHED_HTML="/home/claude/.ttyd-keyboard.html"
KEYBOARD_SNIPPET="${KEYBOARD_SNIPPET:-/home/claude/keyboard-bar.html}"

# Skip if already built and keyboard snippet hasn't changed
if [ -f "$CACHED_HTML" ] && [ "$CACHED_HTML" -nt "$KEYBOARD_SNIPPET" ]; then
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

# Inject keyboard bar snippet before </body> using python3
# (sed can't handle the 700KB single-line ttyd HTML reliably)
python3 - "$KEYBOARD_SNIPPET" /tmp/ttyd-original.html "$CACHED_HTML" << 'PYEOF'
import sys

snippet_path, original_path, output_path = sys.argv[1], sys.argv[2], sys.argv[3]

with open(original_path, 'r') as f:
    html = f.read()
with open(snippet_path, 'r') as f:
    snippet = f.read()

html = html.replace('</body>', snippet + '\n</body>', 1)

with open(output_path, 'w') as f:
    f.write(html)
print('[keyboard] Custom ttyd index built successfully')
PYEOF
