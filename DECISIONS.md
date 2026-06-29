# AI Orchestrator — Architecture Decision Records

## ADR-001: Bash daemon over Python/Node
**Date:** 2026-06  
**Decision:** Core daemon in Bash  
**Why:** Zero dependencies; runs immediately after boot; easy to debug in tmux  
**Consequence:** Limited error handling; regex-only parsing; no async

## ADR-002: claude CLI over direct API calls
**Date:** 2026-06  
**Decision:** Agents invoke `claude` CLI, not Anthropic SDK directly  
**Why:** Inherits all Claude Code features (MCP, tools, session continuity)  
**Consequence:** Harder to instrument token usage; depends on claude CLI version

## ADR-003: Checkpoint-based continuity over --continue
**Date:** 2026-06  
**Decision:** RESUME_STRATEGY=fresh with JSON context injection  
**Why:** `--continue` accumulates unbounded context; fresh+context is token-efficient  
**Consequence:** Each run starts from checkpoint, not full conversation history

## ADR-004: Migration from ~/AI_Orchestartor/ to ~/Projects/ai/AI-Orchestrator/
**Date:** 2026-06-29  
**Decision:** Moved canonical path to Projects/ to match platform spec  
**Why:** Enforce canonical directory structure; eliminate path typo  
**Consequence:** launchd plist updated; old path retained for archival
