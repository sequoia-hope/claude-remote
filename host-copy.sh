#!/bin/bash
# tmux copy-command: put stdin on the HOST desktop clipboard.
#
# The terminal attached to tmux is usually VTE (GNOME Terminal, or the
# overseer desktop window, via docker exec), which ignores OSC 52, so tmux's
# set-clipboard never reaches the desktop. Instead pipe each copy over SSH to
# the host's ~/scripts/clip-copy, which finds the logged-in desktop session
# itself — whichever terminal is attached, or none.
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
    "$HOST_SSH_USER@$HOST_ADDR" '~/scripts/clip-copy'
