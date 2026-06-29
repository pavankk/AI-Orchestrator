# AI Orchestrator

Daemon-managed multi-agent system running Claude CLI agents in tmux sessions. Launchd keeps the daemon alive across reboots. Dashboard (Streamlit) shows live state.

## Repo layout

```
bin/
  orch                  # CLI — main entrypoint (symlinked to ~/.local/bin/orch)
  orch-daemon           # watchdog daemon (started by launchd)
  agent-runner          # runs one agent loop iteration
  asana-sync            # syncs tasks to Asana project
  dashboard             # terminal dashboard (legacy tmux-based)
  export-dashboard-data # writes streamlit/data/*.json snapshots for cloud deploy
agents/<id>/
  config.conf           # per-agent overrides (ENABLED, IDLE_INTERVAL, etc.)
  prompt.md             # system prompt injected at each iteration
config/
  settings.conf         # global defaults — sourced by all scripts
checkpoints/<id>.json   # runtime state: status, iteration, backoff, context
logs/<name>.log         # daemon.log, inbox.log, monitoring.log (rotated at 50MB)
run/
  daemon.pid            # daemon PID
  <id>.heartbeat        # unix timestamp of last agent heartbeat
  <id>.pid              # agent process PID
launchd/
  com.aiorch.plist      # daemon service (auto-start on login)
  com.aiorch.daily.plist# daily Asana sync at 8am
streamlit/
  app.py                # Streamlit dashboard
  requirements.txt      # streamlit>=1.35.0
  .streamlit/config.toml# dark theme
  data/                 # JSON snapshots for Streamlit Cloud deploy
```

## Agent IDs

| ID | Enabled | Interval | Description |
|----|---------|----------|-------------|
| inbox | true | 5m | Email triage, draft replies, extract actions |
| monitoring | true | 5m | Disk/mem/CPU health checks |
| coding | false | 1m | Autonomous coding task queue |
| docs | false | 30m | Detect doc drift, update README/API docs |
| drive-organizer | false | 30m | Watch Google Drive, organize files |
| research | false | 10m | Background research tasks |
| trade-alerts | false | 1h | Check trade alert conditions |

## Common commands

```bash
orch status                   # all agents status
orch start inbox              # start agent in tmux
orch stop inbox               # stop agent
orch enable inbox             # set ENABLED=true in config.conf
orch disable inbox
orch start all                # start all enabled agents
orch health                   # daemon health + heartbeat ages
orch logs inbox               # tail agent log
orch daemon-start             # start watchdog daemon
orch daemon-stop

# Streamlit dashboard
cd streamlit && streamlit run app.py   # local, live data
bin/export-dashboard-data              # write data/ snapshots (for cloud)
bin/export-dashboard-data --commit     # write + git commit snapshots
```

## Dashboard

- **Local** (`streamlit run streamlit/app.py`): reads live from `checkpoints/`, `logs/`, `run/`. Auto-refresh 10–120s (sidebar toggle).
- **Cloud** (Streamlit Community Cloud): reads `streamlit/data/*.json`. Run `bin/export-dashboard-data --commit && git push` to refresh cloud view.
- Deploy: [share.streamlit.io](https://share.streamlit.io) → connect `pavankk/AI-Orchestrator` → main file `streamlit/app.py`.

## Architecture

- **Daemon** (`bin/orch-daemon`): polls every ~30s, restarts agents whose heartbeat is stale >15min.
- **Agent runner** (`bin/agent-runner`): runs one `claude --dangerously-skip-permissions` invocation with the agent's prompt, writes checkpoint, sleeps `IDLE_INTERVAL`.
- **Heartbeat**: agent-runner writes `run/<id>.heartbeat` (unix timestamp) every `CHECKPOINT_INTERVAL` seconds.
- **Backoff**: quota/error hits increase backoff exponentially (5m → 1h cap for quota, 15m cap for errors).
- **Launchd**: `com.aiorch` runs `orch-daemon` at login; restarts on crash.

## Config inheritance

Global defaults in `config/settings.conf`. Each agent's `config.conf` overrides selectively. Scripts source global first, then agent config.

## Key files not committed

`checkpoints/`, `logs/`, `run/` are in `.gitignore` (runtime state). `config/asana.conf` (token). `streamlit/data/` **is** committed (cloud snapshot).

## Prerequisites

`tmux`, `jq`, `python3`, `claude` (Claude Code CLI). Install: `./install.sh`.

## GitHub

`https://github.com/pavankk/AI-Orchestrator` — main branch.
