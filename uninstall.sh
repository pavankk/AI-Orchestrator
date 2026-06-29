#!/usr/bin/env bash
# uninstall.sh — remove launchd service and CLI symlink (keeps agent data)
set -euo pipefail

ORCH_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHD_LABEL="com.aiorch"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/${LAUNCHD_LABEL}.plist"

GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; RESET='\033[0m'
ok()   { printf "${GREEN}✓${RESET} %s\n" "$*"; }
warn() { printf "${YELLOW}!${RESET} %s\n" "$*"; }

echo "${BOLD}AI Orchestrator — Uninstaller${RESET}"
echo

# Stop all agents
"$ORCH_HOME/bin/orch" stop all 2>/dev/null || true

# Unload launchd
if [[ -f "$LAUNCHD_PLIST" ]]; then
    launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
    rm -f "$LAUNCHD_PLIST"
    ok "launchd service removed"
else
    warn "No launchd plist found"
fi

# Remove CLI symlink
if [[ -L "$HOME/.local/bin/orch" ]]; then
    rm "$HOME/.local/bin/orch"
    ok "Removed $HOME/.local/bin/orch"
fi

echo
ok "Uninstalled. Agent data preserved at $ORCH_HOME/{logs,checkpoints}"
echo "Run 'rm -rf $ORCH_HOME' to delete everything."
