# claude-remote

Docker-based setup that runs Claude Code with `--dangerously-skip-permissions` and exposes it via a web terminal (ttyd) accessible only over your private Tailscale network. Open `http://<tailscale-ip>:7681` on your phone to monitor and interact with Claude Code sessions.

## Prerequisites

- Docker and Docker Compose
- Tailscale installed and connected on both your host machine and phone
- Claude Code auth (run `claude login` on the host — token is persisted via `~/.claude` bind mount)

## Quick Start

```bash
cp .env.example .env
# Edit .env: set TAILSCALE_IP, PROJECT_DIR, TTYD_PASS
vim .env

chmod +x run.sh stop.sh
./run.sh
```

## Access from Phone

1. Make sure your phone is on the same Tailnet
2. Open `http://<tailscale-ip>:7681` in mobile Safari or Chrome
3. Enter the basic auth credentials (default: `claude` / `changeme`)
4. You're in a tmux session running Claude Code

## Session Persistence

Claude runs inside tmux. If you close the browser tab or lose connection, the session keeps running. Just reconnect to the same URL and you'll reattach to the live session.

To attach locally from the host:

```bash
docker exec -it claude-remote tmux attach -t claude
```

## Security

- **Network level**: ttyd port is bound to your Tailscale IP only — not reachable from the public internet or local network
- **Application level**: ttyd basic auth (username/password)
- **Change the default password** in `.env` before running

## Configuration

| Variable | Default | Description |
|---|---|---|
| `ANTHROPIC_API_KEY` | (none) | Optional — only needed if not using `claude login` |
| `TAILSCALE_IP` | (auto-detected) | Your machine's Tailscale IPv4 address |
| `PROJECT_DIR` | `.` | Absolute path to the project directory to mount |
| `TTYD_USER` | `claude` | Basic auth username |
| `TTYD_PASS` | `changeme` | Basic auth password |
| `SESSION_NAME` | `claude` | tmux session name (for running multiple instances) |

## Multiple Sessions

Run multiple containers for different projects by using different session names and ports. Create separate compose files or override the port and session name per instance.

## Stretch Goals (Not Implemented)

- **Tailscale inside the container** — container joins the Tailnet directly, ttyd listens on localhost only
- **HTTPS via Tailscale certs** — `tailscale cert` + ttyd `--ssl` flags
- **Push notifications** — webhook when Claude finishes a task or errors
- **Read-only observer mode** — remove ttyd `-W` flag for watch-only access
- **Project-specific toolchains** — extend the Dockerfile with Rust, clang, cmake, etc.
