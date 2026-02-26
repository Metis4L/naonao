#!/usr/bin/env python3
import argparse, json
from datetime import datetime
from pathlib import Path

ADVISORY=Path('projects/naonao-content-ops/reports/advisory-decision.latest.json')
QUEUE_STATE=Path('projects/naonao-content-ops/.auto/queue-state.json')


def load(p,default=None):
    if not p.exists():
        return default if default is not None else {}
    return json.load(open(p,encoding='utf-8'))


def save(p,obj):
    p.parent.mkdir(parents=True, exist_ok=True)
    json.dump(obj,open(p,'w',encoding='utf-8'),ensure_ascii=False,indent=2)


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--gate', required=True)
    args=ap.parse_args()

    adv=load(ADVISORY,{})
    gate=load(Path(args.gate),{"decision":"unknown"})
    state=load(QUEUE_STATE,{"last_run_at":None,"done":[],"blocked":[],"last_selected":None})

    wo=((adv.get('context') or {}).get('selected_wo') or {})
    wo_id=wo.get('wo_id') or ((state.get('last_selected') or {}).get('wo_id'))
    decision=adv.get('decision')

    if not wo_id:
        save(QUEUE_STATE,state)
        print('queue-progress: no selected wo_id')
        return

    if decision != 'auto_proceed':
        state.setdefault('blocked',[]).append({
            'wo_id': wo_id,
            'reason': f'decision={decision}',
            'gate_report_path': args.gate,
            'at': datetime.now().isoformat(timespec='seconds')
        })
        save(QUEUE_STATE,state)
        print('queue-progress: blocked')
        return

    gate_decision=str(gate.get('decision','unknown')).lower()
    if gate_decision == 'pass':
        done=state.setdefault('done',[])
        if wo_id not in done:
            done.append(wo_id)
        state['last_run_at']=datetime.now().isoformat(timespec='seconds')
        state['done_detail']=(state.get('done_detail') or []) + [{
            'wo_id': wo_id,
            'gate_report_path': args.gate,
            'at': datetime.now().isoformat(timespec='seconds')
        }]
    else:
        state.setdefault('blocked',[]).append({
            'wo_id': wo_id,
            'reason': f'gate={gate_decision}',
            'gate_report_path': args.gate,
            'at': datetime.now().isoformat(timespec='seconds')
        })

    save(QUEUE_STATE,state)
    print('queue-progress: updated')


if __name__=='__main__':
    main()
