#!/usr/bin/env python3
import argparse
import json
from datetime import datetime, timezone, timedelta
from pathlib import Path

TZ = timezone(timedelta(hours=8))

ROOT_MANIFEST = Path("projects/naonao-content-ops/handovers/root-manifest.json")
ITER_LEDGER = Path("projects/naonao-content-ops/handovers/iteration-ledger.json")
WO_SHADOW = Path("projects/naonao-content-ops/handovers/work-order-shadow-monitoring.json")

OUT_WO = Path("projects/naonao-content-ops/handovers/generated-work-order.latest.json")
OUT_PLAN = Path("projects/naonao-content-ops/reports/execution-plan.latest.json")
OUT_DECISION = Path("projects/naonao-content-ops/reports/advisory-decision.latest.json")


def now_iso():
    return datetime.now(TZ).isoformat(timespec="seconds")


def load_json(p: Path):
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
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("- run_mode:"):
            run_mode = s.split(":", 1)[1].strip()
        if s.startswith("- baseline_policy:"):
            baseline_policy = s.split(":", 1)[1].strip()
        if s.startswith("- schema_policy:"):
            schema_policy = s.split(":", 1)[1].strip()
        if s.startswith("- semantic_policy:"):
            semantic_policy = s.split(":", 1)[1].strip()

    goal = "未提供目标"
    for line in text.splitlines():
        if line.strip().startswith("- （一句话写清这次要达成的业务目标）"):
            continue
    # super-lightweight extraction
    for i, line in enumerate(text.splitlines()):
        if line.strip() == "## 目标":
            if i + 1 < len(text.splitlines()):
                nxt = text.splitlines()[i + 1].strip()
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
        "raw_text": text,
        "contains_prod_word": ("prod" in lower),
    }


def main():
    ap = argparse.ArgumentParser(description="Compile rough brief into work-order/plan/decision")
    ap.add_argument("--brief", default="projects/naonao-content-ops/handovers/brief.template.md")
    args = ap.parse_args()

    brief = parse_brief(Path(args.brief))
    manifest = load_json(ROOT_MANIFEST)
    ledger = load_json(ITER_LEDGER)
    wo_base = load_json(WO_SHADOW)

    candidate = next((x for x in ledger.get("iterations", []) if x.get("status") == "candidate"), {})

    generated_wo = {
        "task_id": f"wo_generated_{datetime.now(TZ).strftime('%Y%m%d_%H%M%S')}",
        "goal": brief["goal"],
        "run_mode": brief["run_mode"],
        "root_aliases": manifest.get("root_aliases", {}),
        "boundaries": wo_base.get("boundaries", {}),
        "source_brief": str(Path(args.brief)),
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
        "steps": [
            {"id": 1, "name": "preflight", "cmd": "make preflight"},
            {"id": 2, "name": "validate-json", "cmd": "make validate-json"},
            {"id": 3, "name": "shadow-monitoring", "cmd": "make shadow-monitoring"},
        ],
        "candidate_iter": candidate.get("iter_id", "unknown"),
        "baseline_iter": ledger.get("current_baseline", {}).get("iter_id", "unknown"),
    }

    must_approve = []
    if brief["approval_flags"]["needs_baseline_approval"]:
        must_approve.append("baseline_change")
    if brief["approval_flags"]["needs_schema_approval"]:
        must_approve.append("schema_change")
    if brief["approval_flags"]["needs_semantic_approval"]:
        must_approve.append("semantic_change")
    if brief["contains_prod_word"] or brief["run_mode"] == "prod":
        must_approve.append("prod_run")

    advisory_decision = {
        "timestamp": now_iso(),
        "decision": "auto_proceed" if not must_approve else "needs_human_approval",
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
            "baseline_iter": ledger.get("current_baseline", {}).get("iter_id", "unknown")
        }
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
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
