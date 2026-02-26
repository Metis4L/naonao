# Executor Capability Matrix

Last updated: 2026-02-26
Primary executor: `tools/run-selected-work-order.sh`

## Supported operations and modes

| Operation | Supported `change_spec.mode` | Notes |
|---|---|---|
| `ADD` | `full_replace` | Requires `change_spec.content` (string). Target must not exist. |
| `MODIFY` | `full_replace`, `patch`, `append_section`, `structured_write` | `patch` requires `patch_text` JSON string with `old/new`; `structured_write` requires JSON target (`.json`). |
| `MERGE` | `structured_write` | `content` is JSON object string; shallow merge into existing JSON object. |
| `DELETE` | mode ignored (accepted) | Deletes existing file; reports `deleted_sha256` + rollback hint. |

## Non-goals / explicitly unsupported

- `insert_after_heading` is schema-compatible historical field but **not executable** in current executor.
- Directory-level operations are unsupported (file-level only).
- Deep merge (recursive merge) is unsupported; `MERGE` is shallow key overwrite.

## Required field expectations

- `root_alias` must resolve in work-order aliases or root-manifest aliases.
- `path` must stay within resolved root (path traversal blocked).
- `change_spec` must include `mode`; content requirements vary by operation/mode.

## Regression work-order set

- Valid matrix sample: `handovers/work-order-exec-capability-008-valid.json`
- Invalid matrix sample: `handovers/work-order-exec-capability-008-invalid.json`
- Validation report: `reports/executor-capability-regression-report-20260226.md`
