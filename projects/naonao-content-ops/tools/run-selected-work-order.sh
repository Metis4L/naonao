#!/usr/bin/env bash
set -Eeuo pipefail

WORK_ORDER="${1:-${WORK_ORDER:-projects/naonao-content-ops/handovers/work-order-shadow-monitoring.json}}"
RUN_MODE="${2:-${RUN_MODE:-test}}"
ROOT_MANIFEST="projects/naonao-content-ops/handovers/root-manifest.json"
GATE="projects/naonao-content-ops/reports/hard-validator-gate.latest.json"

python3 - <<'PY' "$WORK_ORDER" "$RUN_MODE" "$ROOT_MANIFEST" "$GATE"
import hashlib
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

wo_path, run_mode, manifest_path, gate_path = sys.argv[1:5]
now = datetime.now().isoformat(timespec='seconds')
workspace_root = str(Path.cwd().resolve())

# 失败码规范（与 docs/executor-error-codes.md 对齐）
ERRORS = {
    'OK': ('EXE_OK', 'ok', 'none'),
    'UNKNOWN_ROOT_ALIAS': ('EXE_ROOT_ALIAS_UNKNOWN', 'unknown_root_alias', 'schema_fail'),
    'MISSING_PATH': ('EXE_PATH_MISSING', 'missing_path', 'schema_fail'),
    'PATH_ESCAPE_BLOCKED': ('EXE_PATH_ESCAPE_BLOCKED', 'path_escape_blocked', 'schema_fail'),
    'MISSING_CHANGE_SPEC': ('EXE_CHANGE_SPEC_MISSING', 'missing_change_spec', 'schema_fail'),
    'UNSUPPORTED_OPERATION': ('EXE_OPERATION_UNSUPPORTED', 'unsupported_operation', 'schema_fail'),
    'UNSUPPORTED_MODE': ('EXE_MODE_UNSUPPORTED', 'unsupported_mode', 'schema_fail'),
    'TARGET_NOT_FOUND': ('EXE_TARGET_NOT_FOUND', 'target_not_found', 'exec_fail'),
    'TARGET_ALREADY_EXISTS': ('EXE_TARGET_ALREADY_EXISTS', 'target_already_exists', 'exec_fail'),
    'WRITE_FAILED': ('EXE_WRITE_FAILED', 'write_failed', 'infra_fail'),
    'READ_FAILED': ('EXE_READ_FAILED', 'read_failed', 'infra_fail'),
    'DELETE_FAILED': ('EXE_DELETE_FAILED', 'delete_failed', 'infra_fail'),
    'PATCH_NOT_FOUND': ('EXE_PATCH_OLD_NOT_FOUND', 'patch_old_text_not_found', 'exec_fail'),
    'PATCH_TEXT_INVALID_JSON': ('EXE_PATCH_TEXT_INVALID_JSON', 'patch_text_invalid_json', 'schema_fail'),
    'PATCH_TEXT_MISSING_KEYS': ('EXE_PATCH_TEXT_MISSING_KEYS', 'patch_text_missing_keys', 'schema_fail'),
    'INVALID_JSON_CONTENT': ('EXE_JSON_INVALID_CONTENT', 'invalid_json_content', 'schema_fail'),
    'NON_JSON_TARGET': ('EXE_JSON_TARGET_REQUIRED', 'non_json_target', 'schema_fail'),
    'NON_JSON_EXISTING': ('EXE_JSON_EXISTING_INVALID', 'non_json_existing', 'exec_fail'),
    'NON_OBJECT_JSON': ('EXE_JSON_OBJECT_REQUIRED', 'non_object_json', 'schema_fail'),
}

# 固化支持矩阵：ADD/MODIFY(full_replace,patch,append_section,structured_write)/MERGE/DELETE
CAPABILITY_MATRIX = {
    'ADD': {'allowed_modes': {'full_replace'}},
    'MODIFY': {'allowed_modes': {'full_replace', 'patch', 'append_section', 'structured_write'}},
    'MERGE': {'allowed_modes': {'structured_write'}},
    'DELETE': {'allowed_modes': {'full_replace', 'append_section', 'patch', 'structured_write'}},
}


def err_key(name):
    return ERRORS[name][0]


def err_reason(name):
    return ERRORS[name][1]


def err_class(name):
    return ERRORS[name][2]


def _load_json(path, default=None):
    try:
        with open(path, encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return {} if default is None else default


def _safe_git_head():
    try:
        return subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    except Exception:
        return ''


def _is_within(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except Exception:
        return False


def _sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        while True:
            chunk = f.read(8192)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def _record_fail(result, code_name, detail=None):
    result['status'] = 'failed'
    result['reason_code'] = err_reason(code_name)
    result['error_code'] = err_key(code_name)
    result['error_class'] = err_class(code_name)
    if detail:
        result['detail'] = detail


manifest = _load_json(manifest_path, {}) if Path(manifest_path).exists() else {}
wo = _load_json(wo_path, {})
task_id = wo.get('task_id', 'work_order')
out = Path(f"projects/naonao-content-ops/reports/execution-report-wo_{task_id}.json")

manifest_aliases = (manifest or {}).get('root_aliases') or {}
wo_aliases = (wo or {}).get('root_aliases') or {}
root_aliases = {**manifest_aliases, **wo_aliases}

file_results = []
blocking_issues = []

for idx, f in enumerate(wo.get('files', []) or [], start=1):
    root_alias = f.get('root_alias', 'openclaw')
    rel_path = f.get('path')
    op = str(f.get('operation', '')).upper()
    change_spec = f.get('change_spec') or {}

    result = {
        'index': idx,
        'root_alias': root_alias,
        'relative_path': rel_path,
        'operation': op,
        'status': 'pending',
        'reason_code': '',
        'error_code': '',
        'error_class': '',
    }

    base = root_aliases.get(root_alias)
    if not base:
        _record_fail(result, 'UNKNOWN_ROOT_ALIAS')
        file_results.append(result)
        blocking_issues.append({'code': result['error_code'], 'reason_code': result['reason_code'], 'error_class': result['error_class'], 'file': rel_path, 'root_alias': root_alias})
        continue

    if not rel_path:
        _record_fail(result, 'MISSING_PATH')
        file_results.append(result)
        blocking_issues.append({'code': result['error_code'], 'reason_code': result['reason_code'], 'error_class': result['error_class'], 'root_alias': root_alias})
        continue

    base_path = Path(base).resolve()
    target_path = Path(base_path, rel_path).resolve()
    result['resolved_path'] = str(target_path)

    if not _is_within(target_path, base_path):
        _record_fail(result, 'PATH_ESCAPE_BLOCKED')
        file_results.append(result)
        blocking_issues.append({
            'code': result['error_code'],
            'reason_code': result['reason_code'],
            'error_class': result['error_class'],
            'file': rel_path,
            'root_alias': root_alias,
            'resolved_path': str(target_path),
            'declared_root': str(base_path),
        })
        continue

    before_exists = target_path.exists()
    before_size = target_path.stat().st_size if before_exists else 0
    result['before_exists'] = before_exists
    result['before_size'] = before_size

    mode = str(change_spec.get('mode', '')).lower() if isinstance(change_spec, dict) else ''
    if op not in CAPABILITY_MATRIX:
        _record_fail(result, 'UNSUPPORTED_OPERATION')
    elif mode and mode not in CAPABILITY_MATRIX[op]['allowed_modes']:
        _record_fail(result, 'UNSUPPORTED_MODE', f'unsupported mode: {mode} for operation {op}')

    try:
        if result['status'] == 'failed':
            pass
        elif op == 'ADD':
            if before_exists:
                _record_fail(result, 'TARGET_ALREADY_EXISTS')
            else:
                content = change_spec.get('content')
                if not isinstance(content, str):
                    _record_fail(result, 'MISSING_CHANGE_SPEC', 'ADD requires change_spec.content as string')
                else:
                    target_path.parent.mkdir(parents=True, exist_ok=True)
                    target_path.write_text(content, encoding='utf-8')
                    result.update({'status': 'success', 'reason_code': err_reason('OK'), 'error_code': err_key('OK'), 'error_class': err_class('OK'), 'bytes_written': len(content.encode('utf-8'))})

        elif op == 'MODIFY':
            if not isinstance(change_spec, dict) or 'mode' not in change_spec:
                _record_fail(result, 'MISSING_CHANGE_SPEC')
            else:
                content = change_spec.get('content')

                if mode == 'full_replace':
                    if not isinstance(content, str):
                        _record_fail(result, 'MISSING_CHANGE_SPEC', 'full_replace requires content:string')
                    else:
                        target_path.parent.mkdir(parents=True, exist_ok=True)
                        target_path.write_text(content, encoding='utf-8')
                        result.update({'status': 'success', 'reason_code': err_reason('OK'), 'error_code': err_key('OK'), 'error_class': err_class('OK'), 'mode': mode, 'bytes_written': len(content.encode('utf-8'))})

                elif mode == 'append_section':
                    if not isinstance(content, str):
                        _record_fail(result, 'MISSING_CHANGE_SPEC', 'append_section requires content:string')
                    else:
                        target_path.parent.mkdir(parents=True, exist_ok=True)
                        if not target_path.exists():
                            target_path.write_text('', encoding='utf-8')
                        with open(target_path, 'a', encoding='utf-8') as wf:
                            wf.write(content)
                        result.update({'status': 'success', 'reason_code': err_reason('OK'), 'error_code': err_key('OK'), 'error_class': err_class('OK'), 'mode': mode, 'bytes_appended': len(content.encode('utf-8'))})

                elif mode == 'patch':
                    if not before_exists:
                        _record_fail(result, 'TARGET_NOT_FOUND')
                    else:
                        patch_text = change_spec.get('patch_text')
                        if not isinstance(patch_text, str):
                            _record_fail(result, 'MISSING_CHANGE_SPEC', 'patch requires change_spec.patch_text as string')
                        else:
                            try:
                                patch_obj = json.loads(patch_text)
                            except Exception as e:
                                _record_fail(result, 'PATCH_TEXT_INVALID_JSON', str(e))
                            else:
                                old = patch_obj.get('old') if isinstance(patch_obj, dict) else None
                                new = patch_obj.get('new') if isinstance(patch_obj, dict) else None
                                if not isinstance(old, str) or not isinstance(new, str):
                                    _record_fail(result, 'PATCH_TEXT_MISSING_KEYS')
                                else:
                                    text = target_path.read_text(encoding='utf-8')
                                    if old not in text:
                                        _record_fail(result, 'PATCH_NOT_FOUND')
                                    else:
                                        replaced = text.replace(old, new)
                                        target_path.write_text(replaced, encoding='utf-8')
                                        result.update({
                                            'status': 'success',
                                            'reason_code': err_reason('OK'),
                                            'error_code': err_key('OK'),
                                            'error_class': err_class('OK'),
                                            'mode': mode,
                                            'patch_old': old,
                                            'patch_new': new,
                                        })

                elif mode == 'structured_write':
                    if target_path.suffix.lower() != '.json':
                        _record_fail(result, 'NON_JSON_TARGET')
                    elif not isinstance(content, str):
                        _record_fail(result, 'MISSING_CHANGE_SPEC', 'structured_write requires content:string')
                    else:
                        try:
                            parsed = json.loads(content)
                        except Exception as e:
                            _record_fail(result, 'INVALID_JSON_CONTENT', str(e))
                        else:
                            target_path.parent.mkdir(parents=True, exist_ok=True)
                            target_path.write_text(json.dumps(parsed, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
                            result.update({'status': 'success', 'reason_code': err_reason('OK'), 'error_code': err_key('OK'), 'error_class': err_class('OK'), 'mode': mode})

        elif op == 'DELETE':
            if not before_exists:
                _record_fail(result, 'TARGET_NOT_FOUND')
            else:
                digest = _sha256_of(target_path)
                size = target_path.stat().st_size
                target_path.unlink()
                result.update({
                    'status': 'success',
                    'reason_code': err_reason('OK'),
                    'error_code': err_key('OK'),
                    'error_class': err_class('OK'),
                    'deleted': True,
                    'deleted_sha256': digest,
                    'deleted_size': size,
                    'rollback_hint': f'restore file {rel_path} from backup/git history; sha256={digest}'
                })

        elif op == 'MERGE':
            content = change_spec.get('content')
            if not isinstance(content, str):
                _record_fail(result, 'MISSING_CHANGE_SPEC', 'MERGE requires change_spec.content as JSON string')
            elif target_path.suffix.lower() != '.json':
                _record_fail(result, 'NON_JSON_TARGET')
            else:
                try:
                    patch_obj = json.loads(content)
                except Exception as e:
                    _record_fail(result, 'INVALID_JSON_CONTENT', str(e))
                    patch_obj = None
                if patch_obj is not None:
                    if not isinstance(patch_obj, dict):
                        _record_fail(result, 'NON_OBJECT_JSON', 'merge patch must be JSON object')
                    else:
                        base_obj = {}
                        if before_exists:
                            try:
                                base_obj = json.loads(target_path.read_text(encoding='utf-8'))
                            except Exception as e:
                                _record_fail(result, 'NON_JSON_EXISTING', str(e))
                                base_obj = None
                            if base_obj is not None and not isinstance(base_obj, dict):
                                _record_fail(result, 'NON_OBJECT_JSON', 'existing json must be object for merge')
                                base_obj = None
                        if base_obj is not None:
                            merged = dict(base_obj)
                            merged.update(patch_obj)
                            target_path.parent.mkdir(parents=True, exist_ok=True)
                            target_path.write_text(json.dumps(merged, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
                            result.update({'status': 'success', 'reason_code': err_reason('OK'), 'error_code': err_key('OK'), 'error_class': err_class('OK'), 'merge_keys': sorted(list(patch_obj.keys()))})

    except Exception as e:
        code = 'DELETE_FAILED' if op == 'DELETE' else 'WRITE_FAILED'
        _record_fail(result, code, str(e))

    result['after_exists'] = target_path.exists()
    result['after_size'] = target_path.stat().st_size if target_path.exists() else 0

    if result['status'] != 'success':
        blocking_issues.append({
            'code': result.get('error_code', err_key('WRITE_FAILED')),
            'reason_code': result.get('reason_code', err_reason('WRITE_FAILED')),
            'error_class': result.get('error_class', err_class('WRITE_FAILED')),
            'file': rel_path,
            'operation': op,
            'detail': result.get('detail', ''),
        })

    file_results.append(result)

success_count = sum(1 for r in file_results if r.get('status') == 'success')
fail_count = len(file_results) - success_count

fingerprint = hashlib.sha256(
    json.dumps(manifest, ensure_ascii=False, sort_keys=True).encode('utf-8')
).hexdigest() if manifest else ''

report = {
    'task_id': task_id,
    'status': 'success' if fail_count == 0 else 'failed',
    'run_mode': run_mode,
    'source_work_order': wo_path,
    'finished_at': now,
    'summary': f'executed files: {success_count} success / {fail_count} failed',
    'file_results': file_results,
    'meta': {
        'workspace_root': workspace_root,
        'git_head': _safe_git_head(),
        'root_manifest_fingerprint': fingerprint,
        'root_aliases_used': root_aliases,
        'capability_matrix_version': '2026-02-26.v1',
    },
    'blocking_issues': blocking_issues,
}

out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')

gate_payload = {
    'decision': 'pass' if fail_count == 0 else 'fail',
    'task_id': task_id,
    'work_order': wo_path,
    'validated_at': now,
    'message': 'execution_success' if fail_count == 0 else 'execution_failed',
    'reason': (blocking_issues[0]['code'] if blocking_issues else ''),
    'failure_class': (blocking_issues[0]['error_class'] if blocking_issues else 'none'),
}
Path(gate_path).parent.mkdir(parents=True, exist_ok=True)
Path(gate_path).write_text(json.dumps(gate_payload, ensure_ascii=False, indent=2), encoding='utf-8')

print(str(out))
print(str(gate_path))

if fail_count:
    raise SystemExit(2)
PY
