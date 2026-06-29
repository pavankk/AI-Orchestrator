# AI Orchestrator — Architecture

**Class:** Infrastructure  
**Stack:** Bash, Python 3, tmux, launchd

## System Overview

```
launchd → orch-daemon → tmux sessions → agent-runner → claude CLI
                  ↓
           checkpoints/ (JSON heartbeats)
                  ↓
           Streamlit dashboard (:8501)
```

## Components

| Component | Path | Purpose |
|-----------|------|---------|
| `orch-daemon` | `bin/orch-daemon` | Watchdog: starts/restarts agents, monitors heartbeats |
| `agent-runner` | `bin/agent-runner` | Runs claude in tmux, writes heartbeats |
| `orch` | `bin/orch` | CLI: start/stop/status/enable/disable agents |
| `dashboard` | `bin/dashboard` | Streamlit live status dashboard |
| `asana-sync` | `bin/asana-sync` | Daily sync to Asana (8am via launchd) |

## Agent Lifecycle

```
ENABLED=true in config.conf
    → daemon detects agent not running
    → starts tmux session ai-{agent_id}
    → agent-runner executes claude with prompt.md
    → heartbeat written to run/{agent_id}.heartbeat
    → checkpoint written to checkpoints/{agent_id}.json
    → daemon monitors: stale heartbeat > 1800s → recycle
```

## Runtime Files

| File | Purpose |
|------|---------|
| `run/daemon.pid` | Daemon process ID |
| `run/{id}.pid` | Agent process ID |
| `run/{id}.heartbeat` | Unix timestamp of last agent heartbeat |
| `checkpoints/{id}.json` | Agent state: status, iteration, context |
| `session-registry.json` | All agents: status, config, metrics |

## tmux Session Naming

Prefix: `ai-` + agent_id (e.g., `ai-inbox`, `ai-monitoring`)
