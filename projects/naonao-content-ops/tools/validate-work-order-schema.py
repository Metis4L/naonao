#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

from jsonschema import Draft202012Validator


def load_json(path: Path):
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)


def fmt_path(parts):
    if not parts:
        return '$'
    out = '$'
    for p in parts:
        if isinstance(p, int):
            out += f'[{p}]'
        else:
            out += f'.{p}'
    return out


def main():
    ap = argparse.ArgumentParser(description='Validate selected work-order against schema (hard-fail)')
    ap.add_argument('--work-order', required=True)
    ap.add_argument('--schema', default='projects/naonao-content-ops/contracts/work-order.schema.json')
    ap.add_argument('--out', default='projects/naonao-content-ops/reports/work-order-schema-validation.latest.json')
    ap.add_argument('--gate', default='projects/naonao-content-ops/reports/hard-validator-gate.latest.json')
    args = ap.parse_args()

    work_order_path = Path(args.work_order)
    schema_path = Path(args.schema)

    result = {
        'work_order': str(work_order_path),
        'schema': str(schema_path),
        'ok': False,
        'errors': []
    }

    try:
        schema = load_json(schema_path)
        work_order = load_json(work_order_path)
    except Exception as e:
        result['errors'].append({'path': '$', 'message': f'load_failed: {e}'})
    else:
        # 避免本地相对 $id 导致 jsonschema 远程解析错误
        if isinstance(schema, dict) and '$id' in schema and isinstance(schema.get('$id'), str) and not schema['$id'].startswith(('http://', 'https://', 'file://')):
            schema = dict(schema)
            schema.pop('$id', None)
        validator = Draft202012Validator(schema)
        errs = sorted(validator.iter_errors(work_order), key=lambda e: list(e.absolute_path))
        for e in errs:
            result['errors'].append({
                'path': fmt_path(list(e.absolute_path)),
                'schema_path': fmt_path(list(e.absolute_schema_path)),
                'message': e.message,
            })
        result['ok'] = len(errs) == 0

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')

    gate = {
        'decision': 'pass' if result['ok'] else 'fail',
        'task_id': (work_order.get('task_id') if 'work_order' in locals() and isinstance(work_order, dict) else ''),
        'work_order': str(work_order_path),
        'validated_at': __import__('datetime').datetime.now().isoformat(timespec='seconds'),
        'message': 'work_order_schema_valid' if result['ok'] else 'work_order_schema_invalid',
        'reason': '' if result['ok'] else 'schema_validation_failed',
        'schema_report': str(out_path),
    }
    gate_path = Path(args.gate)
    gate_path.parent.mkdir(parents=True, exist_ok=True)
    gate_path.write_text(json.dumps(gate, ensure_ascii=False, indent=2), encoding='utf-8')

    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(0 if result['ok'] else 2)


if __name__ == '__main__':
    main()
