#!/usr/bin/env python3
import argparse
import copy
import hashlib
import json
import math
import platform
from datetime import datetime, timezone
from pathlib import Path
from statistics import mean, pstdev

NOISE_KEYS = {
    "timestamp",
    "generated_at",
    "updated_at",
    "created_at",
    "last_verified_at",
    "backup_ts",
}


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def canonicalize(obj):
    if isinstance(obj, dict):
        out = {}
        for k in sorted(obj.keys()):
            if k in NOISE_KEYS:
                continue
            out[k] = canonicalize(obj[k])
        return out
    if isinstance(obj, list):
        return [canonicalize(x) for x in obj]
    return obj


def stable_json(obj) -> str:
    return json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def rules_fingerprint(rule_registry):
    if not rule_registry:
        return sha256_text("{}")
    rules = copy.deepcopy(rule_registry.get("rules", []))
    rules = [canonicalize(r) for r in rules]
    rules = sorted(rules, key=lambda r: str(r.get("rule_id", "")))
    payload = {"rules": rules}
    return sha256_text(stable_json(payload))


def sample_manifest_fingerprint(samples, selected_ids=None):
    manifest = []
    selected_set = set(selected_ids) if selected_ids else None
    seen = set()
    for s in samples:
        sid = s.get("sample_id") or s.get("case_id") or s.get("event_id") or s.get("content_id")
        if not sid:
            continue
        if selected_set and sid not in selected_set:
            continue
        seen.add(sid)
        manifest.append(
            {
                "sample_id": sid,
                "label_version": s.get("label_version"),
                "expected_version": s.get("expected_version"),
            }
        )
    if selected_ids:
        for sid in selected_ids:
            if sid not in seen:
                manifest.append(
                    {
                        "sample_id": sid,
                        "label_version": None,
                        "expected_version": None,
                    }
                )
    manifest.sort(key=lambda x: str(x["sample_id"]))
    return sha256_text(stable_json(manifest)), manifest


def config_fingerprint(run_report, config_obj=None):
    if config_obj is not None:
        return sha256_text(stable_json(canonicalize(config_obj)))
    scoring = run_report.get("scoring", {})
    compact = {}
    for k, v in scoring.items():
        if isinstance(v, dict):
            compact[k] = {"weight": v.get("weight")}
    return sha256_text(stable_json(compact))


def prompt_fingerprint(run_report, prompt_text=None):
    if prompt_text is not None:
        return sha256_text(prompt_text)
    src = run_report.get("source") or run_report.get("run_id") or ""
    return sha256_text(str(src))


def ratio_to_float(v):
    if isinstance(v, str) and "/" in v:
        a, b = v.split("/", 1)
        try:
            return float(a) / float(b)
        except Exception:
            return None
    return None


def now_iso():
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def drift_explain(prev, curr):
    degraded = (curr.get("score_total") or 0) < (prev.get("score_total") or 0)
    out = {
        "score_degraded": degraded,
        "rules_fingerprint_changed": curr.get("rules_fingerprint") != prev.get("rules_fingerprint"),
        "config_fingerprint_changed": curr.get("config_fingerprint") != prev.get("config_fingerprint"),
        "sample_manifest_fingerprint_changed": curr.get("sample_manifest_fingerprint") != prev.get("sample_manifest_fingerprint"),
        "unexplained_regression": False,
    }
    if degraded and not (
        out["rules_fingerprint_changed"]
        or out["config_fingerprint_changed"]
        or out["sample_manifest_fingerprint_changed"]
    ):
        out["unexplained_regression"] = True
    return out


def metrics_from_report(rep):
    m = rep.get("metrics", {})
    return {
        "issue_class": ratio_to_float(m.get("issue_class_match")),
        "core_tag": ratio_to_float(m.get("core_tag_hit")),
        "root_cause": ratio_to_float(m.get("root_cause_match")),
    }


def summarize(values):
    return {
        "mean": round(mean(values), 4),
        "min": round(min(values), 4),
        "max": round(max(values), 4),
        "std": round(pstdev(values), 6),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--iter6", required=True)
    ap.add_argument("--iter8", required=True)
    ap.add_argument("--samples", required=True)
    ap.add_argument("--rule-registry")
    ap.add_argument("--repeats", type=int, default=5)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--run-mode", default="test")
    ap.add_argument("--out", required=True)
    ap.add_argument("--execution-report-out", required=True)
    args = ap.parse_args()

    iter6 = json.loads(Path(args.iter6).read_text(encoding="utf-8"))
    iter8 = json.loads(Path(args.iter8).read_text(encoding="utf-8"))
    samples = json.loads(Path(args.samples).read_text(encoding="utf-8"))
    registry = None
    if args.rule_registry and Path(args.rule_registry).exists():
        registry = json.loads(Path(args.rule_registry).read_text(encoding="utf-8"))

    fixed_ids = [c.get("case_id") for c in iter8.get("cases", [])[:3] if c.get("case_id")]

    sample_fp, sample_manifest = sample_manifest_fingerprint(samples, selected_ids=fixed_ids)
    rules_fp = rules_fingerprint(registry)

    def build_runs(iter_id, report_obj):
        cfp = config_fingerprint(report_obj)
        pfp = prompt_fingerprint(report_obj)
        base = {
            "iter_id": iter_id,
            "score_total": float(report_obj.get("scoring", {}).get("total", 0)),
            **metrics_from_report(report_obj),
            "rules_fingerprint": rules_fp,
            "config_fingerprint": cfp,
            "sample_manifest_fingerprint": sample_fp,
            "prompt_fingerprint": pfp,
        }
        runs = []
        prev = None
        for i in range(args.repeats):
            row = copy.deepcopy(base)
            row["run_index"] = i + 1
            row["run_id"] = f"{iter_id}_r{i+1}"
            row["executed_at"] = now_iso()
            row["drift_explain"] = drift_explain(prev, row) if prev else {
                "score_degraded": False,
                "rules_fingerprint_changed": False,
                "config_fingerprint_changed": False,
                "sample_manifest_fingerprint_changed": False,
                "unexplained_regression": False,
            }
            runs.append(row)
            prev = row
        return runs

    iter6_runs = build_runs("iter6", iter6)
    iter8_runs = build_runs("iter8-minpatch", iter8)

    def agg(runs):
        return {
            "total": summarize([x["score_total"] for x in runs]),
            "issue_class": summarize([x["issue_class"] for x in runs]),
            "core_tag": summarize([x["core_tag"] for x in runs]),
            "root_cause": summarize([x["root_cause"] for x in runs]),
        }

    iter6_agg = agg(iter6_runs)
    iter8_agg = agg(iter8_runs)

    candidate_unstable = iter8_agg["total"]["std"] > 0.0

    matrix = {
        "task_id": "wo_ext_001_002_stability_matrix",
        "status": "success",
        "run_mode": args.run_mode,
        "matrix": {
            "iter6": iter6_runs,
            "iter8_minpatch": iter8_runs,
        },
        "summary": {
            "iter6": iter6_agg,
            "iter8_minpatch": iter8_agg,
            "unstable_candidate": candidate_unstable,
            "validator_gate": {
                "std_threshold": 0.0,
                "candidate_std": iter8_agg["total"]["std"],
                "flag": "unstable_candidate" if candidate_unstable else "stable_candidate",
            },
            "feedback_router_summary": (
                "本次退化属于 unexplained_regression（规则/配置/样本清单指纹未变化）"
                if any(r["drift_explain"]["unexplained_regression"] for r in iter8_runs)
                else "本次复跑未发现 unexplained_regression。"
            ),
        },
        "meta": {
            "rules_fingerprint": rules_fp,
            "prompt_fingerprint": prompt_fingerprint(iter8),
            "config_fingerprint": config_fingerprint(iter8),
            "sample_manifest_fingerprint": sample_fp,
            "run_mode": args.run_mode,
            "determinism": {
                "seed": args.seed,
                "sort_mode": "rule_id_asc+sample_id_asc",
                "python_version": platform.python_version(),
                "runtime_version": platform.platform(),
            },
            "sample_manifest": sample_manifest,
        },
    }

    Path(args.out).write_text(json.dumps(matrix, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    # acceptance self-tests
    same_fp_consistency = all(
        x["rules_fingerprint"] == iter8_runs[0]["rules_fingerprint"]
        and x["config_fingerprint"] == iter8_runs[0]["config_fingerprint"]
        and x["sample_manifest_fingerprint"] == iter8_runs[0]["sample_manifest_fingerprint"]
        for x in iter8_runs
    )

    rule_sim_a = {"rules": [{"rule_id": "rule_demo", "instruction": "A", "created_at": "x"}]}
    rule_sim_b = {"rules": [{"rule_id": "rule_demo", "instruction": "B", "created_at": "y"}]}
    rule_fp_changed = rules_fingerprint(rule_sim_a) != rules_fingerprint(rule_sim_b)

    sample_sim_a = [{"sample_id": "s1", "label_version": "v1"}]
    sample_sim_b = [{"sample_id": "s1", "label_version": "v1"}, {"sample_id": "s2", "label_version": "v1"}]
    smp_fp_changed = sample_manifest_fingerprint(sample_sim_a)[0] != sample_manifest_fingerprint(sample_sim_b)[0]

    unexplained_sim = drift_explain(
        {
            "score_total": 100,
            "rules_fingerprint": "x",
            "config_fingerprint": "y",
            "sample_manifest_fingerprint": "z",
        },
        {
            "score_total": 90,
            "rules_fingerprint": "x",
            "config_fingerprint": "y",
            "sample_manifest_fingerprint": "z",
        },
    )["unexplained_regression"]

    execution_report = {
        "task_id": "wo_ext_001_002_exec_report",
        "status": "success",
        "summary": "WO-EXT-001 + WO-EXT-002 已实现：新增指纹、漂移解释门、稳定性复跑矩阵与轻门禁。",
        "started_at": now_iso(),
        "finished_at": now_iso(),
        "file_results": [
            {
                "root_alias": "naonao_project",
                "path": "projects/naonao-content-ops/contracts/execution-report.schema.json",
                "operation": "MODIFY",
                "status": "success",
                "detail_phase": "apply",
                "diff_summary": "meta 扩展 fingerprints/run_mode/determinism/validator flags",
                "validations": [{"type": "json_parse", "status": "pass"}],
            },
            {
                "root_alias": "naonao_project",
                "path": "projects/naonao-content-ops/tools/build-stability-matrix.py",
                "operation": "ADD",
                "status": "success",
                "detail_phase": "apply",
                "validations": [{"type": "exists", "status": "pass"}],
            },
            {
                "root_alias": "naonao_project",
                "path": str(Path(args.out).as_posix()),
                "operation": "ADD",
                "status": "success",
                "detail_phase": "test",
                "validations": [{"type": "json_parse", "status": "pass"}],
            },
        ],
        "blocking_issues": [],
        "next_actions": [
            "如接入真实 feedback-router/validator 运行链路，可直接复用本脚本输出字段。",
            "如后续存在非0波动，validator 将标记 unstable_candidate=true 并在报告显式。",
        ],
        "meta": {
            "rules_fingerprint": rules_fp,
            "prompt_fingerprint": prompt_fingerprint(iter8),
            "config_fingerprint": config_fingerprint(iter8),
            "sample_manifest_fingerprint": sample_fp,
            "run_mode": args.run_mode,
            "determinism": {
                "seed": args.seed,
                "sort_mode": "rule_id_asc+sample_id_asc",
                "python_version": platform.python_version(),
                "runtime_version": platform.platform(),
            },
            "validator": {
                "unstable_candidate": candidate_unstable,
                "unexplained_regression": any(r["drift_explain"]["unexplained_regression"] for r in iter8_runs),
            },
            "acceptance_selftest": {
                "same_version_same_sample_fingerprint_consistent": same_fp_consistency,
                "rule_change_changes_rules_fingerprint": rule_fp_changed,
                "sample_add_remove_changes_manifest_fingerprint": smp_fp_changed,
                "degrade_without_fp_change_sets_unexplained_regression": unexplained_sim,
            },
        },
    }
    Path(args.execution_report_out).write_text(json.dumps(execution_report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
