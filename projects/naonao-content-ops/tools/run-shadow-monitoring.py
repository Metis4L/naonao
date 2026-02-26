#!/usr/bin/env python3
import json
from datetime import datetime, timezone, timedelta
from pathlib import Path

TZ = timezone(timedelta(hours=8))

LEDGER = Path("projects/naonao-content-ops/handovers/iteration-ledger.json")
OUT = Path("projects/naonao-content-ops/reports/correction-regression-shadow-monitoring.json")


def now_iso():
    return datetime.now(TZ).isoformat(timespec="seconds")


def mean(vals):
    return sum(vals) / len(vals) if vals else 0.0


def std(vals):
    if len(vals) < 2:
        return 0.0
    m = mean(vals)
    return (sum((x - m) ** 2 for x in vals) / len(vals)) ** 0.5


def load_json(p):
    with open(p, "r", encoding="utf-8") as f:
        return json.load(f)


def save_json(p, obj):
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)


def main():
    ledger = load_json(LEDGER)

    baseline_iter = ledger.get("current_baseline", {}).get("iter_id", "unknown")
    candidate = next((x for x in ledger.get("iterations", []) if x.get("status") == "candidate"), None)
    if not candidate:
        raise SystemExit("no candidate iteration found")

    candidate_iter = candidate.get("iter_id")
    score = float(candidate.get("score_total", 0.0))

    vals = [score]
    for run in ledger.get("validation_runs", []):
        if run.get("iter_id") == candidate_iter:
            vals.extend(run.get("result", {}).get("score_totals", []) or [])

    snapshot = {
        "timestamp": now_iso(),
        "candidate_iter": candidate_iter,
        "baseline_iter": baseline_iter,
        "score": {
            "mean": round(mean(vals), 4),
            "min": min(vals) if vals else 0.0,
            "max": max(vals) if vals else 0.0,
            "std": round(std(vals), 6),
            "n": len(vals),
        },
        "flags": {
            "unexplained_regression": (mean(vals) + 1e-9) < float(candidate.get("score_total", 0.0)),
            "unstable_candidate": std(vals) > 1e-6,
            "no_production_baseline_overwrite": True,
        },
        "note": "shadow monitoring only; no baseline write",
    }

    monitoring = {"snapshots": []}
    if OUT.exists():
        monitoring = load_json(OUT)
        monitoring.setdefault("snapshots", [])
    monitoring["snapshots"].append(snapshot)
    monitoring["latest"] = snapshot
    save_json(OUT, monitoring)

    ledger.setdefault("validation_runs", []).append({
        "run_id": f"shadow-monitoring-{candidate_iter}-{datetime.now(TZ).strftime('%Y%m%d-%H%M%S')}",
        "iter_id": candidate_iter,
        "track": "shadow_monitoring",
        "mode": "test",
        "status": "completed",
        "result": {
            "snapshot_ref": str(OUT),
            "score_mean": snapshot["score"]["mean"],
            "score_std": snapshot["score"]["std"],
        },
        "postchecks": {
            "no_production_baseline_overwrite": "pass",
            "execution_report_generated": "pass"
        },
        "timestamp": snapshot["timestamp"]
    })
    save_json(LEDGER, ledger)

    print(json.dumps(snapshot, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
