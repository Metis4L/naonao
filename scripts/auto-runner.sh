#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

LOCK_FILE="${AUTO_ADVANCE_LOCK:-/tmp/openclaw_auto_advance.lock}"
AUTO_ADVANCE_MAX_STEPS="${AUTO_ADVANCE_MAX_STEPS:-3}"
QUEUE_FILE="${AUTO_QUEUE_FILE:-$REPO_ROOT/projects/naonao-content-ops/handovers/auto-queue.json}"
QUEUE_STATE_FILE="${QUEUE_STATE_FILE:-$REPO_ROOT/projects/naonao-content-ops/.auto/queue-state.json}"
NOTIFY_CHANNEL="${NOTIFY_CHANNEL:-telegram}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-5667549865}"

notify() {
  local level="$1"
  local text="$2"
  if command -v openclaw >/dev/null 2>&1; then
    openclaw message send --channel "$NOTIFY_CHANNEL" --target "$TELEGRAM_CHAT_ID" --message "[auto-runner:$level] $text" >/dev/null 2>&1 || true
  fi
}

mark_done() {
  python3 - <<'PY'
import json
from datetime import datetime
from pathlib import Path
qf=Path("projects/naonao-content-ops/handovers/auto-queue.json")
sf=Path("projects/naonao-content-ops/.auto/queue-state.json")
if not qf.exists() or not sf.exists():
    raise SystemExit(0)
q=json.loads(qf.read_text(encoding='utf-8'))
s=json.loads(sf.read_text(encoding='utf-8'))
sel=(s.get('last_selected') or {})
wo_id=sel.get('wo_id')
if not wo_id:
    raise SystemExit(0)
for item in q.get('queue',[]):
    if item.get('wo_id')==wo_id and item.get('status','pending')!='done':
        item['status']='done'
        item['done_at']=datetime.now().isoformat(timespec='seconds')
        break
done=s.get('done',[])
if wo_id not in done:
    done.append(wo_id)
s['done']=done
s['last_run_at']=datetime.now().isoformat(timespec='seconds')
sf.parent.mkdir(parents=True, exist_ok=True)
sf.write_text(json.dumps(s,ensure_ascii=False,indent=2),encoding='utf-8')
qf.write_text(json.dumps(q,ensure_ascii=False,indent=2),encoding='utf-8')
PY
}

has_pending_auto() {
  python3 - <<'PY'
import json
from pathlib import Path
p=Path("projects/naonao-content-ops/handovers/auto-queue.json")
if not p.exists():
    print("0"); raise SystemExit
q=json.loads(p.read_text(encoding='utf-8'))
if not q.get('active',False):
    print("0"); raise SystemExit
for item in q.get('queue',[]):
    if item.get('auto') is True and item.get('status','pending')!='done':
        print("1"); raise SystemExit
print("0")
PY
}

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  notify "skip" "auto advance skipped (locked)"
  exit 0
fi

for ((i=1; i<=AUTO_ADVANCE_MAX_STEPS; i++)); do
  if [[ "$(has_pending_auto)" != "1" ]]; then
    notify "idle" "queue empty/inactive, stop auto advance"
    exit 0
  fi

  if ! AUTO_ADVANCE=1 make p15-all; then
    notify "fail" "step=$i 执行失败，停止自动推进"
    exit 1
  fi

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
    notify "approval" "命中 stop rule：requires approval，停止自动推进"
    exit 0
  fi
  if [[ "$decision" == "idle" ]]; then
    notify "idle" "队列为空/未激活，停止自动推进"
    exit 0
  fi

  mark_done
  notify "ok" "step=$i 完成并出队"

done

notify "stop" "达到 AUTO_ADVANCE_MAX_STEPS=$AUTO_ADVANCE_MAX_STEPS，停止本轮"
