# Queue Retry Policy

Last updated: 2026-02-26

## Failure grading

Queue runtime uses 4 classes:

- `schema_fail`
- `exec_fail`
- `gate_fail`
- `infra_fail`

`queue-progress.py` derives class from gate payload (`failure_class` or reason/error code heuristics).

## Retry budget

### Default budget (`auto-queue.json`)

```json
"retry_budget": {
  "default": 2,
  "by_failure_class": {
    "schema_fail": 0,
    "exec_fail": 2,
    "gate_fail": 0,
    "infra_fail": 4
  }
}
```

Meaning: schema/gate failures quarantine immediately unless per-item override exists.

### Per-item override

Each queue item may set:

- `max_attempts`: hard cap for all classes
- `retry_budget_override`: class-level budget overrides

## State transitions

- Success: `status=done`
- Retryable failure and attempts < budget: `status=pending`
- Budget exhausted / non-retriable class: `status=quarantined`
- Explicit `on_fail=skip`: `status=skipped`

## Alerts

Use templates in `docs/queue-alert-templates.md` and include `wo_id`, `failure_class`, `error_code`, `attempt`, `budget`, `report_path`.
