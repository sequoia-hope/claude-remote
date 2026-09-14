#!/bin/bash
# tmux copy-command: put stdin on the HOST desktop clipboard.
#
# The terminal attached to tmux (GNOME Terminal via shell.sh -> docker exec)
# is VTE, which ignores OSC 52, so tmux's set-clipboard never reaches the
# desktop. Instead pipe each copy over SSH to the host, where xclip writes
# into the logged-in session through Mutter's Xwayland (GNOME syncs that to
# the Wayland clipboard). Xwayland's XAUTHORITY file is renamed every login,
# so it is read from the running terminal server's environment each time.
set -euo pipefail

HOST_SSH_USER="${HOST_SSH_USER:-sequoia}"

# Docker host = this container's default gateway (/proc/net/route is
# little-endian hex, so reverse the octets).
if [ -z "${HOST_ADDR:-}" ]; then
    gw=$(awk '$2 == "00000000" { print $3; exit }' /proc/net/route)
    [ -n "$gw" ] || { echo "host-copy: no default route to the docker host" >&2; exit 1; }
    HOST_ADDR=$(printf '%d.%d.%d.%d' "0x${gw:6:2}" "0x${gw:4:2}" "0x${gw:2:2}" "0x${gw:0:2}")
fi

exec ssh -T -o BatchMode=yes -o ConnectTimeout=3 \
    -o UserKnownHostsFile="$HOME/.claude/host_known_hosts" \
    "$HOST_SSH_USER@$HOST_ADDR" '
# Match the exact (15-char-truncated) process name: -f would also match
# this very shell, whose command line contains the string.
p=$(pgrep -u "$(id -u)" -n -x gnome-terminal-) \
    || { echo "host-copy: no GNOME Terminal in a desktop session" >&2; exit 1; }
eval "$(tr "\0" "\n" < /proc/$p/environ | grep -E "^(DISPLAY|XAUTHORITY)=" | sed "s/^/export /")"
# xclip stays behind to own the selection; detach its stdio so ssh can exit.
exec xclip -selection clipboard -i >/dev/null 2>&1'
