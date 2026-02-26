# Executor Capability Regression Report (2026-02-26)

## Scope

- Executor: `tools/run-selected-work-order.sh`
- Matrix target: `ADD / MODIFY(full_replace,patch,append_section,structured_write) / MERGE / DELETE`
- Samples:
  - valid: `handovers/work-order-exec-capability-008-valid.json`
  - invalid: `handovers/work-order-exec-capability-008-invalid.json`

## Commands

```bash
# valid sample
bash projects/naonao-content-ops/tools/run-selected-work-order.sh \
  projects/naonao-content-ops/handovers/work-order-exec-capability-008-valid.json apply

# invalid sample (expected non-zero)
bash projects/naonao-content-ops/tools/run-selected-work-order.sh \
  projects/naonao-content-ops/handovers/work-order-exec-capability-008-invalid.json apply
```

## Results

### Valid sample

- Exit code: `0`
- Execution report: `reports/execution-report-wo_wo_exec_cap_008_valid.json`
- Summary: `7 success / 0 failed`
- Coverage:
  - ADD ✅
  - MODIFY + append_section ✅
  - MODIFY + patch ✅
  - MODIFY + structured_write ✅
  - MERGE ✅
  - DELETE ✅

### Invalid sample

- Exit code: `2` (expected)
- Execution report: `reports/execution-report-wo_wo_exec_cap_008_invalid.json`
- Expected fail reason:
  - `error_code=EXE_MODE_UNSUPPORTED`
  - `reason_code=unsupported_mode`
  - `error_class=schema_fail`

## Conclusion

Executor matrix guard and error-code mapping are functioning as expected for this regression set.
