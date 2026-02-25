#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
samples_path = root / 'reports' / 'observation-window-iter8-samples.json'
log_path = root / 'reports' / 'observation-window-iter8-log.json'

samples_obj = json.loads(samples_path.read_text(encoding='utf-8'))
log = json.loads(log_path.read_text(encoding='utf-8'))
samples = samples_obj.get('samples', [])

n = len(samples)
if n == 0:
    log['collected_samples'] = 0
    log['samples'] = []
    log['summary']['issue_class_hit'] = None
    log['summary']['core_tag_hit'] = None
    log['summary']['root_cause_reasonable'] = None
    log['summary']['decision'] = 'awaiting_observation'
else:
    issue_hits = sum(1 for s in samples if s.get('review', {}).get('has_obvious_misclassification') is False)
    exec_hits = sum(1 for s in samples if s.get('review', {}).get('is_executable') is True)
    root_reasonable = sum(1 for s in samples if s.get('prediction', {}).get('root_cause_layer') not in (None, '', 'unknown'))

    log['collected_samples'] = n
    log['samples'] = [s.get('sample_id') for s in samples]
    log['summary']['issue_class_hit'] = round(issue_hits / n, 4)
    log['summary']['core_tag_hit'] = round(exec_hits / n, 4)
    log['summary']['root_cause_reasonable'] = round(root_reasonable / n, 4)

    if n >= log.get('target_samples', 10):
        log['summary']['decision'] = 'ready_for_manual_review'
    else:
        log['summary']['decision'] = 'awaiting_observation'

log_path.write_text(json.dumps(log, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'updated {log_path} with {n} samples')
