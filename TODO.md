# AI Orchestrator — TODO

## High Priority
- [ ] Wire session-registry.json to orch status output (live metrics)
- [ ] Add cost tracking: write to ~/Projects/logs/costs/YYYY-MM-DD.json
- [ ] Enable trade-alerts agent (wire to signalwatch signals)
- [ ] Daily briefing script: pull agent checkpoints + system metrics

## Medium Priority
- [ ] Weekly maintenance script (git prune, log rotation, docker prune)
- [ ] Portability check script (validate all projects for migration readiness)
- [ ] Snapshot-all script (SESSION_STATE.json across all projects)
- [ ] Enable research agent

## Low Priority
- [ ] Mac Mini migrate.sh script
- [ ] Prometheus metrics export from checkpoints
- [ ] Grafana dashboard for agent health
