#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$ROOT/tools/build-stability-matrix.py" \
  --iter6 "$ROOT/reports/correction-regression-run-20260226-real-packe-iter6.json" \
  --iter8 "$ROOT/reports/correction-regression-run-20260226-real-packe-iter8-minpatch.json" \
  --samples "$ROOT/tests/correction-event-samples.json" \
  --repeats 5 \
  --run-mode test \
  --out "$ROOT/reports/correction-regression-stability-iter6-vs-iter8-minpatch-x5.json" \
  --execution-report-out "$ROOT/reports/execution-report-wo-ext-001-002.json"

echo "Generated:"
echo "- $ROOT/reports/correction-regression-stability-iter6-vs-iter8-minpatch-x5.json"
echo "- $ROOT/reports/execution-report-wo-ext-001-002.json"
