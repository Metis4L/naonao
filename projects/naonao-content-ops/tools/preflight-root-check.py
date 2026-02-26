#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

TZ = timezone(timedelta(hours=8))


def now_iso():
    return datetime.now(TZ).isoformat(timespec="seconds")


def sh(cmd):
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True).strip()
        return out, None
    except Exception as e:
        return None, str(e)


def is_subpath(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except Exception:
        return False


def main():
    p = argparse.ArgumentParser(description="Preflight root resolution / drift checker")
    p.add_argument("--manifest", default="projects/naonao-content-ops/handovers/root-manifest.json")
    p.add_argument("--work-order", required=True)
    p.add_argument("--phase", choices=["phase_1_shadow_soft", "phase_2_c_class_hard_fail"], default="phase_1_shadow_soft")
    p.add_argument("--emit", default="")
    args = p.parse_args()

    workspace_root = str(Path.cwd().resolve())
    cwd = str(Path.cwd().resolve())

    git_root, git_root_err = sh(["git", "rev-parse", "--show-toplevel"])
    git_head, git_head_err = sh(["git", "rev-parse", "HEAD"])
    if git_head_err:
        git_head = "nogit"

    blocking_issues = []
    warnings = []

    with open(args.manifest, "r", encoding="utf-8") as f:
        manifest = json.load(f)
    with open(args.work_order, "r", encoding="utf-8") as f:
        wo = json.load(f)

    aliases = manifest.get("root_aliases", {})
    path_table = []

    for item in wo.get("files", []):
        alias = item.get("root_alias")
        rel = item.get("path", "")
        row = {
            "root_alias": alias,
            "relative_path": rel,
        }
        if alias not in aliases:
            row.update({"resolved_path": "UNKNOWN_ALIAS", "exists": False, "blocked": True})
            path_table.append(row)
            blocking_issues.append(f"unknown root_alias: {alias}")
            continue

        root = Path(aliases[alias]).resolve()
        resolved = (root / rel).resolve()
        exists = resolved.exists()
        in_root = is_subpath(resolved, root)
        row.update({
            "resolved_path": str(resolved),
            "exists": exists,
            "in_declared_root": in_root,
            "blocked": (not in_root),
        })
        if not in_root:
            blocking_issues.append(f"path escaped root alias {alias}: {resolved}")
        path_table.append(row)

    run_mode = wo.get("run_mode", "test")
    c_class_keywords = ["baseline", "schema", "contract", "semantic", "compliance", "privacy", "main_flow"]
    wo_text = json.dumps(wo, ensure_ascii=False).lower()
    c_class_risk = any(k in wo_text for k in c_class_keywords)

    status = "pass"
    root_drift_status = "ok"

    if blocking_issues:
        if args.phase == "phase_1_shadow_soft":
            root_drift_status = "warn"
            warnings.extend(blocking_issues)
        else:
            if c_class_risk:
                root_drift_status = "blocked"
                status = "blocked"
            else:
                root_drift_status = "warn"
                warnings.extend(blocking_issues)

    out = {
        "task": "preflight_root_resolution",
        "timestamp": now_iso(),
        "status": status,
        "phase": args.phase,
        "workspace_root": workspace_root,
        "cwd": cwd,
        "git_root": git_root if git_root else "nogit",
        "git_head": git_head,
        "manifest": args.manifest,
        "work_order": args.work_order,
        "run_mode": run_mode,
        "c_class_risk_detected": c_class_risk,
        "root_drift_status": root_drift_status,
        "path_resolution_table": path_table,
        "blocking_issues": blocking_issues if status == "blocked" else [],
        "warnings": warnings,
    }

    if args.emit:
        Path(args.emit).parent.mkdir(parents=True, exist_ok=True)
        with open(args.emit, "w", encoding="utf-8") as f:
            json.dump(out, f, ensure_ascii=False, indent=2)
        print(f"wrote: {args.emit}")

    print(json.dumps(out, ensure_ascii=False, indent=2))
    sys.exit(2 if status == "blocked" else 0)


if __name__ == "__main__":
    main()
