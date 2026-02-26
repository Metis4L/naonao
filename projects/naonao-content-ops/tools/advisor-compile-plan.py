#!/usr/bin/env python3
import argparse
import json
import os
from datetime import datetime, timezone, timedelta
from pathlib import Path

TZ = timezone(timedelta(hours=8))

ROOT_MANIFEST = Path("projects/naonao-content-ops/handovers/root-manifest.json")
ITER_LEDGER = Path("projects/naonao-content-ops/handovers/iteration-ledger.json")
WO_SHADOW = Path("projects/naonao-content-ops/handovers/work-order-shadow-monitoring.json")
AUTO_QUEUE = Path("projects/naonao-content-ops/handovers/auto-queue.json")
QUEUE_STATE = Path("projects/naonao-content-ops/.auto/queue-state.json")

OUT_WO = Path("projects/naonao-content-ops/handovers/generated-work-order.latest.json")
OUT_PLAN = Path("projects/naonao-content-ops/reports/execution-plan.latest.json")
OUT_DECISION = Path("projects/naonao-content-ops/reports/advisory-decision.latest.json")
OUT_APPROVAL_DIR = Path("projects/naonao-content-ops/reports/approval-packets")
OUT_IDLE_DIR = Path("projects/naonao-content-ops/reports/idle-reports")


def now_iso():
    return datetime.now(TZ).isoformat(timespec="seconds")


def load_json(p: Path, default=None):
    if not p.exists():
        if default is None:
            raise FileNotFoundError(p)
        return default
    with open(p, "r", encoding="utf-8") as f:
        return json.load(f)


def save_json(p: Path, obj):
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)


def parse_brief(path: Path):
    text = path.read_text(encoding="utf-8")
    run_mode = "test"
    baseline_policy = "no_overwrite"
    schema_policy = "compat_add_only"
    semantic_policy = "no_change"

    lower = text.lower()
    lines = text.splitlines()
    for line in lines:
        s = line.strip()
        if s.startswith("- run_mode:"):
            v = s.split(":", 1)[1].strip()
            if "|" not in v:
                run_mode = v
        if s.startswith("- baseline_policy:"):
            v = s.split(":", 1)[1].strip()
            if "|" not in v:
                baseline_policy = v
        if s.startswith("- schema_policy:"):
            v = s.split(":", 1)[1].strip()
            if "|" not in v:
                schema_policy = v
        if s.startswith("- semantic_policy:"):
            v = s.split(":", 1)[1].strip()
            if "|" not in v:
                semantic_policy = v

    goal = "未提供目标"
    for i, line in enumerate(lines):
        if line.strip() == "## 目标" and i + 1 < len(lines):
            nxt = lines[i + 1].strip()
            if nxt:
                goal = nxt.lstrip("- ").strip()
            break

    approval_flags = {
        "needs_baseline_approval": (baseline_policy != "no_overwrite"),
        "needs_schema_approval": (schema_policy != "compat_add_only"),
        "needs_semantic_approval": (semantic_policy != "no_change"),
    }

    return {
        "goal": goal,
        "run_mode": run_mode,
        "baseline_policy": baseline_policy,
        "schema_policy": schema_policy,
        "semantic_policy": semantic_policy,
        "approval_flags": approval_flags,
        "contains_prod_word": False,
    }


def is_c_class(item: dict) -> bool:
    cls = str(item.get("class", "")).strip().lower()
    if cls in {"c", "class_c", "class-c", "approval_c"}:
        return True
    c_keywords = {"baseline", "contract", "schema", "semantic", "compliance", "rearchitecture", "major_refactor"}
    if cls in c_keywords:
        return True
    if item.get("requires_approval") is True:
        return True
    if str(item.get("risk_level", "")).upper() == "C":
        return True
    return False


def first_pending_auto(queue: list, done_ids: list):
    indexed = list(enumerate(queue))
    indexed.sort(key=lambda pair: pair[1].get("priority", 999999))
    for idx, item in indexed:
        if item.get("wo_id") in done_ids:
            continue
        if item.get("status", "pending") == "done":
            continue
        if item.get("auto") is True:
            return idx, item
    return None, None


def write_approval_packet(item: dict, reason: str):
    ts = datetime.now(TZ).strftime("%Y%m%d-%H%M%S")
    p = OUT_APPROVAL_DIR / f"approval-packet-{ts}.json"
    payload = {
        "timestamp": now_iso(),
        "type": "approval_required",
        "reason": reason,
        "wo": item,
        "question": "该任务属于 C 类高风险范围，是否批准执行？（批准/拒绝）"
    }
    save_json(p, payload)
    return p


def write_idle_report(queue_cfg: dict, queue_state: dict, health: dict):
    ts = datetime.now(TZ).strftime("%Y%m%d-%H%M%S")
    p = OUT_IDLE_DIR / f"idle-report-{ts}.json"
    payload = {
        "timestamp": now_iso(),
        "type": "idle",
        "reason": "queue_empty_or_inactive",
        "active": queue_cfg.get("active", False),
        "completed": queue_state.get("done", []),
        "health_signals": health,
        "top3_suggestions": [
            "补充新的 auto=true WO 到 auto-queue.json",
            "执行漂移快照并写入 shadow monitoring",
            "整理候选迭代晋升材料（仅草案）"
        ]
    }
    save_json(p, payload)
    return p


def main():
    ap = argparse.ArgumentParser(description="Compile brief/queue into work-order/plan/decision")
    ap.add_argument("--brief", default="projects/naonao-content-ops/handovers/brief.template.md")
    ap.add_argument("--auto-queue", default=str(AUTO_QUEUE))
    ap.add_argument("--queue-state", default=str(QUEUE_STATE))
    args = ap.parse_args()

    auto_advance = os.getenv("AUTO_ADVANCE", "0") == "1"

    brief = parse_brief(Path(args.brief))
    manifest = load_json(ROOT_MANIFEST)
    ledger = load_json(ITER_LEDGER)
    wo_base = load_json(WO_SHADOW)
    queue_cfg = load_json(Path(args.auto_queue), default={"active": False, "queue": []})
    queue_state = load_json(Path(args.queue_state), default={"last_run_at": None, "done": [], "blocked": [], "last_selected": None})

    candidate = next((x for x in ledger.get("iterations", []) if x.get("status") == "candidate"), {})
    selected_item = None
    selected_work_order = str(WO_SHADOW)
    decision = "auto_proceed"
    must_approve = []
    artifacts = {}

    if auto_advance and queue_cfg.get("active", False):
        idx, item = first_pending_auto(queue_cfg.get("queue", []), queue_state.get("done", []))
        if item is None:
            idle_path = write_idle_report(queue_cfg, queue_state, {
                "baseline_iter": ledger.get("current_baseline", {}).get("iter_id", "unknown"),
                "candidate_iter": candidate.get("iter_id", "unknown")
            })
            decision = "idle"
            artifacts["idle_report"] = str(idle_path)
        elif is_c_class(item) and queue_cfg.get("stop_when", {}).get("requires_approval_class_C", True):
            p = write_approval_packet(item, "C_class_requires_human_approval")
            decision = "needs_human_approval"
            must_approve.append("class_C_task")
            artifacts["approval_packet"] = str(p)
        else:
            selected_item = item
            selected_work_order = item.get("path", str(WO_SHADOW))
            queue_state["last_selected"] = {
                "wo_id": item.get("wo_id"),
                "path": selected_work_order,
                "queue_index": idx,
                "selected_at": now_iso()
            }
            queue_state["last_run_at"] = now_iso()
            save_json(Path(args.queue_state), queue_state)

    generated_wo = {
        "task_id": f"wo_generated_{datetime.now(TZ).strftime('%Y%m%d_%H%M%S')}",
        "goal": brief["goal"],
        "run_mode": brief["run_mode"],
        "root_aliases": manifest.get("root_aliases", {}),
        "boundaries": wo_base.get("boundaries", {}),
        "source_brief": str(Path(args.brief)),
        "selected_from_auto_queue": selected_item,
        "selected_work_order": selected_work_order,
        "advisory": {
            "baseline_policy": brief["baseline_policy"],
            "schema_policy": brief["schema_policy"],
            "semantic_policy": brief["semantic_policy"],
        },
        "files": wo_base.get("files", []),
        "postchecks": wo_base.get("postchecks", []),
        "rollback_required": False,
    }

    execution_plan = {
        "plan_id": f"plan_{datetime.now(TZ).strftime('%Y%m%d_%H%M%S')}",
        "timestamp": now_iso(),
        "mode": brief["run_mode"],
        "selected_work_order": selected_work_order,
        "auto_advance": auto_advance,
        "meta": {
            "auto_selected_wo_id": (selected_item or {}).get("wo_id"),
            "auto_selected_work_order_path": selected_work_order,
        },
        "steps": [
            {"id": 1, "name": "preflight", "cmd": f"make preflight WORK_ORDER={selected_work_order}"},
            {"id": 2, "name": "validate-json", "cmd": "make validate-json"},
            {"id": 3, "name": "execute-work-order", "cmd": f"make execute-work-order WORK_ORDER={selected_work_order} RUN_MODE={brief['run_mode']}"},
            {"id": 4, "name": "shadow-monitoring", "cmd": "make shadow-monitoring"},
        ],
        "candidate_iter": candidate.get("iter_id", "unknown"),
        "baseline_iter": ledger.get("current_baseline", {}).get("iter_id", "unknown"),
        "artifacts": artifacts,
    }

    if brief["approval_flags"]["needs_baseline_approval"]:
        must_approve.append("baseline_change")
    if brief["approval_flags"]["needs_schema_approval"]:
        must_approve.append("schema_change")
    if brief["approval_flags"]["needs_semantic_approval"]:
        must_approve.append("semantic_change")
    if brief["contains_prod_word"] or brief["run_mode"] == "prod":
        must_approve.append("prod_run")

    if must_approve and decision == "auto_proceed":
        decision = "needs_human_approval"

    if decision != "auto_proceed":
        execution_plan["steps"] = [
            {"id": 1, "name": "validate-json", "cmd": "make validate-json"}
        ]

    advisory_decision = {
        "timestamp": now_iso(),
        "decision": decision,
        "must_approve_items": must_approve,
        "safe_auto_scope": [
            "preflight",
            "json_validation",
            "shadow_monitoring",
            "report_generation"
        ],
        "blocked_auto_scope": [
            "baseline_promotion",
            "baseline_overwrite",
            "schema_semantic_change_without_approval"
        ],
        "context": {
            "goal": brief["goal"],
            "run_mode": brief["run_mode"],
            "candidate_iter": candidate.get("iter_id", "unknown"),
            "baseline_iter": ledger.get("current_baseline", {}).get("iter_id", "unknown"),
            "selected_work_order": selected_work_order,
            "selected_wo": selected_item,
        },
        "artifacts": artifacts,
    }

    save_json(OUT_WO, generated_wo)
    save_json(OUT_PLAN, execution_plan)
    save_json(OUT_DECISION, advisory_decision)

    print(json.dumps({
        "generated_work_order": str(OUT_WO),
        "execution_plan": str(OUT_PLAN),
        "advisory_decision": str(OUT_DECISION),
        "decision": advisory_decision["decision"],
        "must_approve_items": must_approve,
        "selected_work_order": selected_work_order,
        "artifacts": artifacts,
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
