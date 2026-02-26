#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
from statistics import pstdev


def load_json(path: Path):
    return json.loads(path.read_text(encoding='utf-8'))


def main():
    ap = argparse.ArgumentParser(description='Generate weekly observation report for iter8')
    ap.add_argument('--input', default='projects/naonao-content-ops/handovers/observation-window-iter8-week1.json')
    ap.add_argument('--output', default='projects/naonao-content-ops/reports/weekly-observation-iter8-week1.latest.json')
    args = ap.parse_args()

    payload = load_json(Path(args.input))
    samples = payload.get('samples', [])
    threshold = payload.get('rollback_threshold', {})

    total = len(samples)
    failed = sum(1 for s in samples if s.get('status') != 'success')
    scores = [float(s.get('score', 0.0)) for s in samples]

    std = pstdev(scores) if len(scores) > 1 else 0.0
    failure_rate = (failed / total) if total else 0.0

    trig_by_fail = failure_rate >= float(threshold.get('failure_rate_gte', 1.0))
    trig_by_std = std >= float(threshold.get('std_gte', 1.0))

    report = {
        'track_id': payload.get('track_id'),
        'window': payload.get('window', {}),
        'metrics': {
            'total_runs': total,
            'failed_runs': failed,
            'failure_rate': round(failure_rate, 4),
            'score_std': round(std, 4)
        },
        'rollback_threshold': {
            'failure_rate_gte': threshold.get('failure_rate_gte'),
            'std_gte': threshold.get('std_gte')
        },
        'rollback_triggered': bool(trig_by_fail or trig_by_std),
        'rollback_trigger_reason': {
            'failure_rate_triggered': trig_by_fail,
            'std_triggered': trig_by_std
        }
    }

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(str(out))


if __name__ == '__main__':
    main()
