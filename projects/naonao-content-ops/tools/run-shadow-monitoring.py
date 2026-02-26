#!/usr/bin/env python3
import json
import os
from datetime import datetime, timezone, timedelta
from pathlib import Path

TZ = timezone(timedelta(hours=8))

LEDGER = Path("projects/naonao-content-ops/handovers/iteration-ledger.json")
OUT = Path("projects/naonao-content-ops/reports/correction-regression-shadow-monitoring.json")
POLICY = Path("projects/naonao-content-ops/handovers/shadow-monitoring-policy.json")


def now_dt():
    return datetime.now(TZ)


def now_iso():
    return now_dt().isoformat(timespec="seconds")


def mean(vals):
    return sum(vals) / len(vals) if vals else 0.0


def std(vals):
    if len(vals) < 2:
        return 0.0
    m = mean(vals)
    return (sum((x - m) ** 2 for x in vals) / len(vals)) ** 0.5


def load_json(p, default=None):
    if not p.exists():
        return {} if default is None else default
    with open(p, "r", encoding="utf-8") as f:
        return json.load(f)


def save_json(p, obj):
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)


def in_quiet_hours(policy):
    q = (policy.get("quiet_hours") or {})
    if not q.get("enabled", False):
        return False
    start = q.get("start", "23:00")
    end = q.get("end", "08:00")
    n = now_dt().strftime("%H:%M")
    if start <= end:
        return start <= n <= end
    return n >= start or n <= end


def should_throttle(policy, monitoring, candidate_iter, snapshot_flags):
    if not policy.get("enabled", True):
        return False, "policy_disabled"

    trig = policy.get("trigger_conditions", {})
    force_var = trig.get("force_env_var", "FORCE_SHADOW_MONITORING")
    if os.getenv(force_var, "0") == "1":
        return False, "forced"

    latest = monitoring.get("latest") or {}
    if latest:
        # event-driven bypasses
        if trig.get("allow_on_candidate_change", True) and latest.get("candidate_iter") != candidate_iter:
            return False, "candidate_changed"
        if trig.get("allow_on_unexplained_regression", True) and snapshot_flags.get("unexplained_regression"):
            return False, "unexplained_regression"
        if trig.get("allow_on_unstable_candidate", True) and snapshot_flags.get("unstable_candidate"):
            return False, "unstable_candidate"

        # quiet window check
        if in_quiet_hours(policy):
            return True, "quiet_hours"

        # min interval check
        last_ts = latest.get("timestamp")
        if last_ts:
            try:
                last_dt = datetime.fromisoformat(last_ts)
                delta_min = (now_dt() - last_dt).total_seconds() / 60
                if delta_min < float(policy.get("min_interval_minutes", 30)):
                    return True, f"min_interval<{policy.get('min_interval_minutes',30)}m"
            except Exception:
                pass

    return False, "ok"


def main():
    ledger = load_json(LEDGER)
    policy = load_json(POLICY, default={"enabled": True, "min_interval_minutes": 30})

    baseline_iter = ledger.get("current_baseline", {}).get("iter_id", "unknown")
    candidate = next((x for x in ledger.get("iterations", []) if x.get("status") in {"candidate", "baseline"} and x.get("iter_id") != baseline_iter), None)
    if not candidate:
        # fallback to historical candidate
        candidate = next((x for x in ledger.get("iterations", []) if x.get("iter_id") == "iter8-minpatch"), None)
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

    monitoring = load_json(OUT, default={"snapshots": []})
    monitoring.setdefault("snapshots", [])

    throttled, reason = should_throttle(policy, monitoring, candidate_iter, snapshot["flags"])
    if throttled:
        print(json.dumps({
            "status": "skipped",
            "reason": reason,
            "policy": str(POLICY),
            "candidate_iter": candidate_iter,
            "baseline_iter": baseline_iter,
        }, ensure_ascii=False, indent=2))
        return

    monitoring["snapshots"].append(snapshot)
    monitoring["latest"] = snapshot
    monitoring["policy_applied"] = {
        "min_interval_minutes": policy.get("min_interval_minutes", 30),
        "quiet_hours": policy.get("quiet_hours", {}),
        "alert_thresholds": policy.get("alert_thresholds", {}),
    }
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
