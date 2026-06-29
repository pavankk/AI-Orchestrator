"""AI Orchestrator Dashboard — works locally (live files) and on Streamlit Community Cloud (data/ snapshots)."""

import json
import os
import re
import time
from datetime import datetime, timezone
from pathlib import Path

import streamlit as st

st.set_page_config(
    page_title="AI Orchestrator",
    page_icon="🤖",
    layout="wide",
    initial_sidebar_state="collapsed",
)

SCRIPT_DIR = Path(__file__).parent
REPO_ROOT = SCRIPT_DIR.parent
DATA_DIR = SCRIPT_DIR / "data"

CHECKPOINTS_DIR = REPO_ROOT / "checkpoints"
LOGS_DIR = REPO_ROOT / "logs"
RUN_DIR = REPO_ROOT / "run"
AGENTS_DIR = REPO_ROOT / "agents"

IS_LOCAL = CHECKPOINTS_DIR.exists() and LOGS_DIR.exists()

AGENT_IDS = [
    "coding", "docs", "drive-organizer",
    "inbox", "monitoring", "research", "trade-alerts",
]

STATUS_ICON = {
    "running": "🟢",
    "idle": "🟡",
    "stopped": "🔴",
    "error": "🔴",
    "disabled": "⚫",
    "unknown": "⚪",
}


def ago(ts_str: str) -> str:
    try:
        dt = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
        s = int((datetime.now(timezone.utc) - dt).total_seconds())
        if s < 60:   return f"{s}s ago"
        if s < 3600: return f"{s // 60}m ago"
        if s < 86400: return f"{s // 3600}h ago"
        return f"{s // 86400}d ago"
    except Exception:
        return ts_str or "—"


def _cfg_val(path: Path, key: str) -> str | None:
    try:
        m = re.search(rf'^{key}="?([^"#\n]+)"?', path.read_text(), re.MULTILINE)
        return m.group(1).strip() if m else None
    except Exception:
        return None


def _heartbeat_age(agent_id: str) -> int | None:
    try:
        ts = int((RUN_DIR / f"{agent_id}.heartbeat").read_text().strip())
        return int(time.time()) - ts
    except Exception:
        return None


def _load_live_agents() -> list[dict]:
    agents = []
    for aid in AGENT_IDS:
        cfg = AGENTS_DIR / aid / "config.conf"
        ckpt_path = CHECKPOINTS_DIR / f"{aid}.json"

        enabled = _cfg_val(cfg, "ENABLED") == "true"
        description = _cfg_val(cfg, "DESCRIPTION") or aid
        try:
            idle_interval = int((_cfg_val(cfg, "IDLE_INTERVAL") or "300").split("#")[0].strip())
        except Exception:
            idle_interval = 300

        ckpt: dict = {}
        try:
            ckpt = json.loads(ckpt_path.read_text())
        except Exception:
            pass

        hb_age = _heartbeat_age(aid) if enabled else None

        if not enabled:
            status = "disabled"
        elif ckpt.get("status") == "running":
            status = "running"
        elif hb_age is not None and hb_age < 900:
            status = "idle"
        elif ckpt:
            status = "stopped"
        else:
            status = "unknown"

        agents.append({
            "id": aid,
            "description": description,
            "enabled": enabled,
            "status": status,
            "iteration": ckpt.get("iteration", 0),
            "last_checkpoint": ckpt.get("last_checkpoint", ""),
            "backoff": ckpt.get("backoff", 0),
            "context": ckpt.get("context", ""),
            "idle_interval": idle_interval,
            "heartbeat_age_s": hb_age,
        })
    return agents


def _load_live_system() -> dict:
    pid_path = RUN_DIR / "daemon.pid"
    daemon_running = False
    daemon_pid = None
    try:
        daemon_pid = int(pid_path.read_text().strip())
        os.kill(daemon_pid, 0)
        daemon_running = True
    except Exception:
        pass
    return {
        "daemon_running": daemon_running,
        "daemon_pid": daemon_pid,
        "last_export": datetime.now(timezone.utc).isoformat(),
        "is_live": True,
    }


def _load_live_logs(n: int = 150) -> dict:
    result = {}
    for name in ["daemon", "inbox", "monitoring"]:
        try:
            lines = (LOGS_DIR / f"{name}.log").read_text().splitlines()
            result[name] = lines[-n:]
        except Exception:
            result[name] = []
    return result


def _load_static(filename: str, default):
    try:
        return json.loads((DATA_DIR / filename).read_text())
    except Exception:
        return default


@st.cache_data(ttl=15)
def load_data() -> tuple[list, dict, dict]:
    if IS_LOCAL:
        return _load_live_agents(), _load_live_system(), _load_live_logs()
    return (
        _load_static("agents.json", []),
        _load_static("system.json", {"daemon_running": False, "last_export": ""}),
        _load_static("logs.json", {}),
    )


# ── Layout ────────────────────────────────────────────────────────────────────

st.title("🤖 AI Orchestrator")

with st.sidebar:
    st.header("Controls")
    auto_refresh = st.toggle("Auto-refresh", value=IS_LOCAL)
    refresh_interval = st.selectbox("Interval", [10, 30, 60, 120], index=1,
                                    format_func=lambda x: f"{x}s")
    if st.button("↺ Refresh now"):
        st.cache_data.clear()
        st.rerun()
    st.divider()
    st.caption(f"Mode: **{'Live' if IS_LOCAL else 'Cloud (snapshot)'}**")
    if not IS_LOCAL:
        st.caption("Data from last export commit. Auto-refresh shows same snapshot.")

agents, system, logs = load_data()

# ── Summary metrics ────────────────────────────────────────────────────────────

c1, c2, c3, c4 = st.columns(4)
enabled = [a for a in agents if a["enabled"]]
active  = [a for a in agents if a["status"] in ("running", "idle")]
total_iters = sum(a.get("iteration", 0) for a in agents)
last_export = system.get("last_export", "")

with c1:
    icon = "🟢" if system.get("daemon_running") else "🔴"
    label = "Running" if system.get("daemon_running") else "Stopped"
    st.metric("Daemon", f"{icon} {label}")
with c2:
    st.metric("Active / Enabled", f"{len(active)} / {len(enabled)}")
with c3:
    st.metric("Total Iterations", f"{total_iters:,}")
with c4:
    st.metric("Last Updated", ago(last_export) if last_export else "—")

st.divider()

# ── Agent cards ────────────────────────────────────────────────────────────────

st.subheader("Agents")

sorted_agents = sorted(agents, key=lambda a: (not a["enabled"], a["id"]))
cols = st.columns(3)

for i, ag in enumerate(sorted_agents):
    with cols[i % 3]:
        icon = STATUS_ICON.get(ag["status"], "⚪")
        with st.container(border=True):
            header_l, header_r = st.columns([3, 1])
            with header_l:
                st.markdown(f"**{icon} {ag['id']}**")
            with header_r:
                st.caption(f"#{ag.get('iteration', 0):,}")

            st.caption(ag.get("description", ""))

            sl, sr = st.columns(2)
            with sl:
                st.caption(f"Status: `{ag['status'].upper()}`")
            with sr:
                hb = ag.get("heartbeat_age_s")
                if hb is not None:
                    hb_str = f"{hb // 60}m ago" if hb >= 60 else f"{hb}s ago"
                    st.caption(f"♡ {hb_str}")

            if ag.get("last_checkpoint"):
                st.caption(f"Checked: {ago(ag['last_checkpoint'])}")

            if ag.get("backoff", 0) > 0:
                st.warning(f"Backoff: {ag['backoff']}s", icon="⏳")

            ctx = (ag.get("context") or "").strip()
            if ctx:
                lines = ctx.splitlines()
                status_line = next((l for l in reversed(lines) if "STATUS:" in l), None)
                snippet = (status_line or lines[-1])[:140]
                st.code(snippet, language=None)

st.divider()

# ── Log viewer ─────────────────────────────────────────────────────────────────

st.subheader("Logs")

log_names = [k for k in logs if logs[k]]
if log_names:
    tabs = st.tabs([n.capitalize() for n in log_names])
    for tab, name in zip(tabs, log_names):
        with tab:
            lines = logs[name]
            n_show = st.slider("Lines", 10, 200, 50, key=f"log_{name}")
            st.code("\n".join(lines[-n_show:]), language=None)
else:
    st.caption("No log data.")

# ── Auto-refresh ───────────────────────────────────────────────────────────────

if auto_refresh:
    time.sleep(refresh_interval)
    st.cache_data.clear()
    st.rerun()
