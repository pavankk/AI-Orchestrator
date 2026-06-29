# AI Orchestrator — Changelog

## [Unreleased]
### Changed
- Migrated canonical path from ~/AI_Orchestartor/ to ~/Projects/ai/AI-Orchestrator/
- Updated launchd plist to point to new canonical path
- Created session-registry.json with all 7 registered agents

## [0.3.0] — 2026-06-29
### Added
- Streamlit dashboard (Streamlit :8501)
- Cloud snapshot deploy for dashboard

## [0.2.0] — 2026-06
### Added
- CLAUDE.md with project architecture
- Daily Asana sync via launchd

## [0.1.0] — 2026-06
### Added
- Initial Claude session orchestrator
- Watchdog daemon with heartbeat monitoring
- tmux session management for inbox + monitoring agents
