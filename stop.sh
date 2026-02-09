#!/bin/bash

# Need TAILSCALE_IP set for compose to parse the file
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi
if [ -z "$TAILSCALE_IP" ]; then
    export TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "127.0.0.1")
fi

docker compose down
echo "Claude remote terminal stopped."
