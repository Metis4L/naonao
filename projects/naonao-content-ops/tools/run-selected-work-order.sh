#!/usr/bin/env bash
set -Eeuo pipefail

WORK_ORDER="${1:-${WORK_ORDER:-projects/naonao-content-ops/handovers/work-order-shadow-monitoring.json}}"
RUN_MODE="${2:-${RUN_MODE:-test}}"
ROOT_MANIFEST="projects/naonao-content-ops/handovers/root-manifest.json"

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

OUT="projects/naonao-content-ops/reports/execution-report-${TASK_ID}.json"
GATE="projects/naonao-content-ops/reports/hard-validator-gate.latest.json"

python3 - <<'PY' "$WORK_ORDER" "$RUN_MODE" "$OUT" "$GATE" "$ROOT_MANIFEST"
import hashlib, json, os, subprocess, sys
from datetime import datetime
from pathlib import Path

wo, run_mode, out, gate, manifest_path = sys.argv[1:6]
now = datetime.now().isoformat(timespec='seconds')

manifest = json.load(open(manifest_path, encoding='utf-8')) if Path(manifest_path).exists() else {}
root_aliases = manifest.get('root_aliases', {})
expected_root = root_aliases.get('openclaw')
workspace_root = os.getcwd()
git_head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()

fingerprint = hashlib.sha256(json.dumps(manifest, ensure_ascii=False, sort_keys=True).encode('utf-8')).hexdigest() if manifest else ''

def resolve_from_work_order(path):
    try:
        data = json.load(open(path, encoding='utf-8'))
    except Exception:
        return []
    rows = []
    for f in data.get('files', []):
        rel = f.get('path')
        alias = f.get('root_alias', 'openclaw')
        base = root_aliases.get(alias)
        resolved = str(Path(base, rel).resolve()) if base and rel else ''
        rows.append({
            'root_alias': alias,
            'relative_path': rel,
            'resolved_path': resolved,
            'exists': Path(resolved).exists() if resolved else False,
            'in_declared_root': resolved.startswith(str(Path(base).resolve())) if base and resolved else False
        })
    return rows

path_resolution_table = resolve_from_work_order(wo)

drift = False
reason = ''
if expected_root and str(Path(workspace_root).resolve()) != str(Path(expected_root).resolve()):
    drift = True
    reason = 'workspace_root_mismatch'

gate_decision = 'pass'
if drift:
    gate_decision = 'fail'

try:
    wo_data = json.load(open(wo, encoding='utf-8'))
except Exception:
    wo_data = {'task_id': 'work_order'}

report = {
    'task_id': wo_data.get('task_id', 'work_order'),
    'status': 'failed' if drift else 'success',
    'run_mode': run_mode,
    'source_work_order': wo,
    'finished_at': now,
    'summary': 'execute-work-order wrapper completed',
    'meta': {
        'workspace_root': workspace_root,
        'git_head': git_head,
        'root_manifest_fingerprint': fingerprint,
        'path_resolution_table': path_resolution_table,
        'root_drift_status': 'blocked' if drift else 'ok'
    },
    'blocking_issues': ([{'code': reason, 'message': 'workspace root mismatch'}] if drift else [])
}

json.dump(report, open(out, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)

gate_payload = {
    'decision': gate_decision,
    'task_id': wo_data.get('task_id', 'work_order'),
    'work_order': wo,
    'validated_at': now,
    'root_drift_status': 'fail' if drift else 'ok',
    'root_drift_phase': 'phase_2_C_class_hard_fail' if drift else 'phase_1_shadow_soft',
    'message': 'conditional_pass_shadow_only_keep_baseline' if not drift else 'blocked_by_workspace_guard'
}
json.dump(gate_payload, open(gate, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)

print(out)
print(gate)

if drift:
    raise SystemExit(2)
PY
