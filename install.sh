#!/usr/bin/env bash
# install.sh — one-time setup for the AI Orchestrator
# Safe to re-run; idempotent.
set -euo pipefail

ORCH_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHD_LABEL="com.aiorch"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/${LAUNCHD_LABEL}.plist"
PLIST_TEMPLATE="$ORCH_HOME/launchd/com.aiorch.plist"
BIN_LINK="$HOME/.local/bin/orch"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; RESET='\033[0m'
ok()   { printf "${GREEN}✓${RESET} %s\n" "$*"; }
info() { printf "${BOLD}→${RESET} %s\n" "$*"; }
warn() { printf "${YELLOW}!${RESET} %s\n" "$*"; }
err()  { printf "${RED}✗${RESET} %s\n" "$*" >&2; }

echo
echo "${BOLD}AI Orchestrator — Installer${RESET}"
echo "Home: $ORCH_HOME"
echo

# ── 1. Prerequisite checks ───────────────────────────────────────────────────

info "Checking prerequisites..."
MISSING=()
for cmd in tmux jq python3 claude; do
    if command -v "$cmd" &>/dev/null; then
        ok "$cmd found at $(command -v "$cmd")"
    else
        err "$cmd not found"
        MISSING+=("$cmd")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo
    err "Missing: ${MISSING[*]}"
    echo "Install tmux with: brew install tmux"
    echo "Install jq with:   brew install jq"
    echo "Install claude:    npm install -g @anthropic-ai/claude-code"
    exit 1
fi

# ── 2. Create runtime directories ────────────────────────────────────────────

info "Creating runtime directories..."
for d in logs checkpoints run; do
    mkdir -p "$ORCH_HOME/$d"
    ok "Created $ORCH_HOME/$d"
done

# Create workspace dirs for each agent
for agent_dir in "$ORCH_HOME/agents"/*/; do
    agent_id=$(basename "$agent_dir")
    workspace="$HOME/ai-workspace/$agent_id"
    mkdir -p "$workspace"
    ok "Workspace: $workspace"
done

# ── 3. Make scripts executable ───────────────────────────────────────────────

info "Setting permissions..."
chmod +x "$ORCH_HOME/bin/orch" \
          "$ORCH_HOME/bin/agent-runner" \
          "$ORCH_HOME/bin/orch-daemon" \
          "$ORCH_HOME/bin/dashboard"
ok "Permissions set"

# ── 4. Symlink orch to /usr/local/bin ────────────────────────────────────────

info "Installing orch CLI..."
mkdir -p "$HOME/.local/bin"
if [[ -L "$BIN_LINK" ]]; then
    rm "$BIN_LINK"
fi
ln -s "$ORCH_HOME/bin/orch" "$BIN_LINK"
ok "Installed: $BIN_LINK → $ORCH_HOME/bin/orch"

# ── 5. Generate and install launchd plist ────────────────────────────────────

info "Installing launchd service..."
mkdir -p "$HOME/Library/LaunchAgents"

sed \
    -e "s|ORCH_HOME_PLACEHOLDER|$ORCH_HOME|g" \
    -e "s|HOME_PLACEHOLDER|$HOME|g" \
    "$PLIST_TEMPLATE" > "$LAUNCHD_PLIST"

ok "Plist written: $LAUNCHD_PLIST"

# Use modern bootstrap API (macOS 10.10+); bootout first if already loaded
local uid
uid=$(id -u)
launchctl bootout "gui/$uid" "$LAUNCHD_PLIST" 2>/dev/null || true
sleep 1

launchctl bootstrap "gui/$uid" "$LAUNCHD_PLIST" 2>/dev/null || \
    launchctl load -w "$LAUNCHD_PLIST"  # fallback for older macOS
ok "launchd service bootstrapped: $LAUNCHD_LABEL"

# macOS 15 (Sequoia) requires explicit enable for RunAtLoad to fire
launchctl enable "gui/$uid/$LAUNCHD_LABEL" 2>/dev/null || true
ok "launchd service enabled"

# Kick it off immediately without waiting for next login
launchctl start "$LAUNCHD_LABEL" 2>/dev/null || true

# ── 6. Install daily Asana sync job ──────────────────────────────────────────

info "Installing daily Asana sync (8am)..."
local DAILY_PLIST="$HOME/Library/LaunchAgents/com.aiorch.daily.plist"
local DAILY_LABEL="com.aiorch.daily"
chmod +x "$ORCH_HOME/bin/asana-sync"
sed \
    -e "s|ORCH_HOME_PLACEHOLDER|$ORCH_HOME|g" \
    -e "s|HOME_PLACEHOLDER|$HOME|g" \
    "$ORCH_HOME/launchd/com.aiorch.daily.plist" > "$DAILY_PLIST"
launchctl bootout "gui/$uid" "$DAILY_PLIST" 2>/dev/null || true
sleep 1
launchctl bootstrap "gui/$uid" "$DAILY_PLIST" 2>/dev/null || true
launchctl enable "gui/$uid/$DAILY_LABEL" 2>/dev/null || true
ok "Daily Asana sync scheduled at 8am"

# ── 7. Verify daemon started ──────────────────────────────────────────────────

sleep 3
if launchctl list | grep -q "$LAUNCHD_LABEL"; then
    local daemon_pid
    daemon_pid=$(launchctl list | awk "/$LAUNCHD_LABEL/{print \$1}")
    if [[ "$daemon_pid" != "-" && -n "$daemon_pid" ]]; then
        ok "Daemon running (PID $daemon_pid)"
    else
        warn "Daemon registered but not yet running — try: orch daemon-start"
    fi
else
    warn "Daemon may not be registered — check: launchctl list | grep aiorch"
fi

# ── 7. Summary ───────────────────────────────────────────────────────────────

echo
echo "${BOLD}Installation complete!${RESET}"
echo
echo "Next steps:"
echo "  1. Enable the agents you want to run:"
echo "       orch enable inbox"
echo "       orch enable monitoring"
echo
echo "  2. Start them manually now:"
echo "       orch start all"
echo
echo "  3. Open the dashboard:"
echo "       orch dashboard"
echo
echo "  4. The watchdog daemon will auto-restart agents after reboots."
echo "     Check daemon status with:  orch health"
echo
echo "  5. Customize agent prompts in: $ORCH_HOME/agents/<name>/prompt.md"
echo
echo "${BOLD}Asana integration:${RESET}"
echo "  6. Get a token at https://app.asana.com/0/my-apps"
echo "     then edit: $ORCH_HOME/config/asana.conf"
echo "     then run:  python3 $ORCH_HOME/bin/asana-sync"
echo "     (creates 'Agent Orchestration Tracker' project automatically)"
echo
echo "${BOLD}On Mac mini:${RESET} copy this folder, run install.sh again. Zero code changes needed."
echo
