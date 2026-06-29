# AI Orchestrator

**Class:** Infrastructure  
**Stack:** Bash, Python 3, tmux, launchd, Streamlit

## What It Does

Platform operating system for all AI agents. Manages agent lifecycle, heartbeat monitoring,
session continuity, and provides a live status dashboard.

**Active agents:** inbox (Gmail triage), monitoring (system health)  
**Daemon:** launchd → orch-daemon → tmux sessions → claude CLI

## Running

```bash
make status      # check all agents
make health      # daemon health
make dashboard   # open Streamlit dashboard (:8501)
orch enable inbox && orch start inbox   # enable + start an agent
```

## Environment Variables

See `.env.example`

## Running on a New Machine

```bash
cp .env.example .env
# Fill in ANTHROPIC_API_KEY, ASANA_TOKEN
bash install.sh
```

## Key Commands

```bash
orch status          # all agent status
orch start all       # start enabled agents
orch stop all        # stop all agents
orch enable <id>     # enable agent
orch disable <id>    # disable agent
orch health          # daemon health check
orch dashboard       # Streamlit live view
```
