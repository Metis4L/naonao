# Queue Alert Templates

## 1) Schema failure (non-retriable by default)

```text
[queue-alert][schema_fail]
wo_id={wo_id}
attempt={attempt}/{budget}
error_code={error_code}
reason={reason}
action=quarantine_and_fix_work_order
report={report_path}
```

## 2) Execution failure (limited retry)

```text
[queue-alert][exec_fail]
wo_id={wo_id}
attempt={attempt}/{budget}
error_code={error_code}
reason={reason}
action=retry_with_budget
report={report_path}
```

## 3) Gate failure (policy/check denied)

```text
[queue-alert][gate_fail]
wo_id={wo_id}
gate_decision={gate_decision}
reason={reason}
action=manual_review_required
report={report_path}
```

## 4) Infrastructure failure (transient)

```text
[queue-alert][infra_fail]
wo_id={wo_id}
attempt={attempt}/{budget}
error_code={error_code}
reason={reason}
action=retry_backoff_then_escalate
report={report_path}
```

## 5) Quarantine reached

```text
[queue-alert][quarantined]
wo_id={wo_id}
attempts={attempts}
final_class={failure_class}
reason={reason}
action=human_intervention_required
```
