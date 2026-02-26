#!/usr/bin/env python3
import argparse, json
from datetime import datetime
from pathlib import Path

ADVISORY = Path('projects/naonao-content-ops/reports/advisory-decision.latest.json')
QUEUE_STATE = Path('projects/naonao-content-ops/.auto/queue-state.json')
QUEUE_FILE = Path('projects/naonao-content-ops/handovers/auto-queue.json')


def now():
    return datetime.now().isoformat(timespec='seconds')


def load(p, default=None):
    if not p.exists():
        return default if default is not None else {}
    with open(p, encoding='utf-8') as f:
        return json.load(f)


def save(p, obj):
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, 'w', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)


def get_selected(adv, state):
    wo = ((adv.get('context') or {}).get('selected_wo') or {})
    wo_id = wo.get('wo_id') or ((state.get('last_selected') or {}).get('wo_id'))
    wo_path = wo.get('path') or ((state.get('last_selected') or {}).get('path'))
    return wo_id, wo_path


def get_policy(queue_item, queue_cfg):
    global_max = int(queue_cfg.get('max_attempts', 3))
    max_attempts = int(queue_item.get('max_attempts', global_max))
    on_fail = queue_item.get('on_fail', 'retry')
    return max_attempts, on_fail


def mark_queue_item(queue_cfg, wo_id, **fields):
    for item in queue_cfg.get('queue', []):
        if item.get('wo_id') == wo_id:
            item.update(fields)
            return item
    return {}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--gate', required=False, default='projects/naonao-content-ops/reports/hard-validator-gate.latest.json')
    ap.add_argument('--stage', choices=['pre', 'post'], default='post')
    args = ap.parse_args()

    adv = load(ADVISORY, {})
    gate = load(Path(args.gate), {'decision': 'unknown'})
    state = load(QUEUE_STATE, {'last_run_at': None, 'done': [], 'blocked': [], 'in_flight': None, 'attempts': {}, 'last_error': {}, 'last_selected': None})
    queue_cfg = load(QUEUE_FILE, {'active': False, 'queue': []})

    wo_id, wo_path = get_selected(adv, state)
    decision = adv.get('decision')

    if not wo_id:
        save(QUEUE_STATE, state)
        print('queue-progress: no selected wo_id')
        return

    item = mark_queue_item(queue_cfg, wo_id)
    max_attempts, on_fail = get_policy(item, queue_cfg)

    if args.stage == 'pre':
        state['in_flight'] = {'wo_id': wo_id, 'path': wo_path, 'started_at': now()}
        state['last_run_at'] = now()
        save(QUEUE_STATE, state)
        save(QUEUE_FILE, queue_cfg)
        print('queue-progress: in_flight set')
        return

    # post stage
    state['in_flight'] = None

    if decision != 'auto_proceed':
        state.setdefault('blocked', []).append({
            'wo_id': wo_id,
            'reason': f'decision={decision}',
            'gate_report_path': args.gate,
            'at': now()
        })
        save(QUEUE_STATE, state)
        save(QUEUE_FILE, queue_cfg)
        print('queue-progress: blocked')
        return

    gate_decision = str(gate.get('decision', 'unknown')).lower()
    if gate_decision == 'pass':
        done = state.setdefault('done', [])
        if wo_id not in done:
            done.append(wo_id)
        state['last_run_at'] = now()
        state['done_detail'] = (state.get('done_detail') or []) + [{
            'wo_id': wo_id,
            'gate_report_path': args.gate,
            'at': now()
        }]
        mark_queue_item(queue_cfg, wo_id, status='done', done_at=now())
    else:
        attempts = state.setdefault('attempts', {})
        attempts[wo_id] = int(attempts.get(wo_id, 0)) + 1
        state.setdefault('last_error', {})[wo_id] = {
            'reason': f'gate={gate_decision}',
            'gate_report_path': args.gate,
            'at': now()
        }
        state.setdefault('blocked', []).append({
            'wo_id': wo_id,
            'reason': f'gate={gate_decision}',
            'gate_report_path': args.gate,
            'at': now()
        })

        if attempts[wo_id] >= max_attempts:
            mark_queue_item(queue_cfg, wo_id, status='quarantined', quarantined_at=now())
        elif on_fail == 'skip':
            mark_queue_item(queue_cfg, wo_id, status='skipped', skipped_at=now())
        elif on_fail == 'quarantine':
            mark_queue_item(queue_cfg, wo_id, status='quarantined', quarantined_at=now())
        else:
            mark_queue_item(queue_cfg, wo_id, status='pending')

    save(QUEUE_STATE, state)
    save(QUEUE_FILE, queue_cfg)
    print('queue-progress: updated')


if __name__ == '__main__':
    main()
