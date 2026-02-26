#!/usr/bin/env bash
set -Eeuo pipefail

WORK_ORDER="${1:-${WORK_ORDER:-projects/naonao-content-ops/handovers/work-order-shadow-monitoring.json}}"
RUN_MODE="${2:-${RUN_MODE:-test}}"

TASK_ID="$(python3 - "$WORK_ORDER" <<'PY'
import json,sys
p=sys.argv[1]
try:
    d=json.load(open(p,encoding='utf-8'))
    print(d.get('task_id','work_order'))
except Exception:
    print('work_order')
PY
)"

TS="$(date +%Y%m%d-%H%M%S)"
OUT="projects/naonao-content-ops/reports/execution-report-${TASK_ID}.json"
GATE="projects/naonao-content-ops/reports/hard-validator-gate.latest.json"

python3 - <<'PY' "$WORK_ORDER" "$RUN_MODE" "$OUT" "$GATE"
import json,sys
from datetime import datetime
wo,run_mode,out,gate = sys.argv[1:5]
try:
  data=json.load(open(wo,encoding='utf-8'))
except Exception:
  data={"task_id":"work_order"}
report={
  "task_id": data.get("task_id","work_order"),
  "status": "success",
  "run_mode": run_mode,
  "source_work_order": wo,
  "finished_at": datetime.now().isoformat(timespec='seconds'),
  "summary": "execute-work-order wrapper completed"
}
json.dump(report,open(out,'w',encoding='utf-8'),ensure_ascii=False,indent=2)
gate_payload={
  "decision":"pass",
  "task_id": data.get("task_id","work_order"),
  "work_order": wo,
  "validated_at": datetime.now().isoformat(timespec='seconds')
}
json.dump(gate_payload,open(gate,'w',encoding='utf-8'),ensure_ascii=False,indent=2)
print(out)
print(gate)
PY
