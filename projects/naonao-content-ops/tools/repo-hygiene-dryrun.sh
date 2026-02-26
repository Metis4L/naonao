#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

OUT="projects/naonao-content-ops/reports/repo-hygiene-dryrun-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$OUT")"

echo "[repo-hygiene] root=$ROOT" > "$OUT"
echo "[repo-hygiene] generated_at=$(date -Iseconds)" >> "$OUT"

echo "\n## candidates: bak files" >> "$OUT"
find . -type f \( -name "*.bak" -o -name "*.bak.*" \) | sort >> "$OUT" || true

echo "\n## candidates: transient execution reports" >> "$OUT"
find projects/naonao-content-ops/reports -type f \( -name "execution-report-*.json" -o -name "*latest*.json" \) | sort >> "$OUT" || true

echo "\n## candidates: pycache" >> "$OUT"
find . -type d -name "__pycache__" | sort >> "$OUT" || true

echo "\n## git status (porcelain)" >> "$OUT"
git status --porcelain >> "$OUT" || true

echo "$OUT"
