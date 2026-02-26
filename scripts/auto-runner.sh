#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

LOCK_FILE="${AUTO_ADVANCE_LOCK:-/tmp/openclaw_auto_advance.lock}"
AUTO_ADVANCE_MAX_STEPS="${AUTO_ADVANCE_MAX_STEPS:-3}"
NOTIFY_CHANNEL="${NOTIFY_CHANNEL:-telegram}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-5667549865}"
SUMMARY_FILE="projects/naonao-content-ops/reports/auto-advance-run-summary.latest.json"

notify() {
  local level="$1"
  local text="$2"
  if command -v openclaw >/dev/null 2>&1; then
    openclaw message send --channel "$NOTIFY_CHANNEL" --target "$TELEGRAM_CHAT_ID" --message "[auto-runner:$level] $text" >/dev/null 2>&1 || true
  fi
}

init_summary() {
  python3 - <<'PY'
import json, subprocess, os
from datetime import datetime
s={
  'run_id': datetime.now().strftime('auto-%Y%m%d-%H%M%S'),
  'start_at': datetime.now().isoformat(timespec='seconds'),
  'end_at': None,
  'steps_attempted': 0,
  'wo_executed': [],
  'stop_reason': None,
  'repo_head': subprocess.check_output(['git','rev-parse','HEAD'], text=True).strip(),
  'workspace_root': os.getcwd()
}
json.dump(s, open('projects/naonao-content-ops/reports/auto-advance-run-summary.latest.json','w',encoding='utf-8'), ensure_ascii=False, indent=2)
PY
}

update_summary_step() {
  local step="$1"
  python3 - <<'PY' "$step"
import json,sys
p='projects/naonao-content-ops/reports/auto-advance-run-summary.latest.json'
s=json.load(open(p,encoding='utf-8'))
s['steps_attempted']=int(sys.argv[1])
json.dump(s,open(p,'w',encoding='utf-8'),ensure_ascii=False,indent=2)
PY
}

append_wo() {
  local duration="$1"
  python3 - <<'PY' "$duration"
import json,sys
from pathlib import Path
p='projects/naonao-content-ops/reports/auto-advance-run-summary.latest.json'
s=json.load(open(p,encoding='utf-8'))
adv=Path('projects/naonao-content-ops/reports/advisory-decision.latest.json')
gate=Path('projects/naonao-content-ops/reports/hard-validator-gate.latest.json')
wo_id=None
wo_path=None
gate_decision='unknown'
if adv.exists():
    a=json.load(open(adv,encoding='utf-8'))
    selected=(a.get('context') or {}).get('selected_wo') or {}
    wo_id=selected.get('wo_id') or ((a.get('context') or {}).get('selected_work_order'))
    wo_path=selected.get('path') or (a.get('context') or {}).get('selected_work_order')
if gate.exists():
    gate_decision=json.load(open(gate,encoding='utf-8')).get('decision','unknown')
s['wo_executed'].append({
    'wo_id': wo_id,
    'work_order_path': wo_path,
    'gate_decision': gate_decision,
    'duration_sec': float(sys.argv[1])
})
json.dump(s,open(p,'w',encoding='utf-8'),ensure_ascii=False,indent=2)
PY
}

finish_summary() {
  local reason="$1"
  python3 - <<'PY' "$reason"
import json,sys,subprocess
from datetime import datetime
p='projects/naonao-content-ops/reports/auto-advance-run-summary.latest.json'
s=json.load(open(p,encoding='utf-8'))
s['end_at']=datetime.now().isoformat(timespec='seconds')
s['stop_reason']=sys.argv[1]
s['repo_head']=subprocess.check_output(['git','rev-parse','HEAD'], text=True).strip()
json.dump(s,open(p,'w',encoding='utf-8'),ensure_ascii=False,indent=2)
PY
}

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  notify "skip" "auto-advance blocked: reason=locked"
  exit 0
fi

init_summary

for ((i=1; i<=AUTO_ADVANCE_MAX_STEPS; i++)); do
  update_summary_step "$i"
  t0=$(date +%s)

  if ! AUTO_ADVANCE=1 make p15-all; then
    finish_summary "failed_step"
    notify "failed" "auto-advance failed: step=$i"
    exit 1
  fi

  t1=$(date +%s)
  dur=$((t1 - t0))

  decision="$(python3 - <<'PY'
import json
from pathlib import Path
p=Path('projects/naonao-content-ops/reports/advisory-decision.latest.json')
if not p.exists():
    print('auto_proceed')
else:
    print(json.loads(p.read_text(encoding='utf-8')).get('decision','auto_proceed'))
PY
)"

  if [[ "$decision" == "needs_human_approval" ]]; then
    finish_summary "needs_human_approval"
    notify "approval" "auto-advance ok: progressed $((i-1)), stopped=needs_human_approval"
    exit 0
  fi
  if [[ "$decision" == "idle" ]]; then
    finish_summary "idle"
    notify "ok" "auto-advance ok: progressed $((i-1)), stopped=idle"
    exit 0
  fi

  append_wo "$dur"

done

finish_summary "max_steps_reached"
notify "stop" "auto-advance ok: progressed $AUTO_ADVANCE_MAX_STEPS, stopped=max_steps_reached"
