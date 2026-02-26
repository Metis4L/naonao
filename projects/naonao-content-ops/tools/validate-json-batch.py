#!/usr/bin/env python3
import argparse
import glob
import json
from pathlib import Path


def main():
    p = argparse.ArgumentParser(description="Batch JSON parse validator")
    p.add_argument("--paths", nargs="*", default=[
        "projects/naonao-content-ops/contracts/*.json",
        "projects/naonao-content-ops/handovers/*.json",
        "projects/naonao-content-ops/reports/*.json",
    ])
    args = p.parse_args()

    files = []
    for pat in args.paths:
        files.extend(glob.glob(pat))
    files = sorted(set(files))

    bad = []
    for f in files:
        try:
            with open(f, "r", encoding="utf-8") as fp:
                json.load(fp)
        except Exception as e:
            bad.append((f, str(e)))

    print(f"checked={len(files)} bad={len(bad)}")
    for f, e in bad[:100]:
        print(f"BAD {f} :: {e}")

    Path("projects/naonao-content-ops/reports").mkdir(parents=True, exist_ok=True)
    out = {
        "task": "validate_json_batch",
        "checked": len(files),
        "bad": len(bad),
        "errors": [{"path": f, "error": e} for f, e in bad],
    }
    with open("projects/naonao-content-ops/reports/validate-json-batch.latest.json", "w", encoding="utf-8") as fp:
        json.dump(out, fp, ensure_ascii=False, indent=2)

    raise SystemExit(1 if bad else 0)


if __name__ == "__main__":
    main()
