# Executor Error Codes

Last updated: 2026-02-26
Source of truth: `tools/run-selected-work-order.sh` (`ERRORS` map)

## Code table

| error_code | reason_code | class | Meaning |
|---|---|---|---|
| `EXE_OK` | `ok` | `none` | Success |
| `EXE_ROOT_ALIAS_UNKNOWN` | `unknown_root_alias` | `schema_fail` | Unknown root alias |
| `EXE_PATH_MISSING` | `missing_path` | `schema_fail` | Path missing |
| `EXE_PATH_ESCAPE_BLOCKED` | `path_escape_blocked` | `schema_fail` | Path traversal blocked |
| `EXE_CHANGE_SPEC_MISSING` | `missing_change_spec` | `schema_fail` | Required change fields missing |
| `EXE_OPERATION_UNSUPPORTED` | `unsupported_operation` | `schema_fail` | Operation outside supported matrix |
| `EXE_MODE_UNSUPPORTED` | `unsupported_mode` | `schema_fail` | Mode unsupported under operation |
| `EXE_TARGET_NOT_FOUND` | `target_not_found` | `exec_fail` | Target file does not exist |
| `EXE_TARGET_ALREADY_EXISTS` | `target_already_exists` | `exec_fail` | ADD target already exists |
| `EXE_PATCH_OLD_NOT_FOUND` | `patch_old_text_not_found` | `exec_fail` | Patch `old` text not found |
| `EXE_PATCH_TEXT_INVALID_JSON` | `patch_text_invalid_json` | `schema_fail` | `patch_text` is not valid JSON |
| `EXE_PATCH_TEXT_MISSING_KEYS` | `patch_text_missing_keys` | `schema_fail` | `patch_text` missing `old/new` |
| `EXE_JSON_INVALID_CONTENT` | `invalid_json_content` | `schema_fail` | Invalid JSON content string |
| `EXE_JSON_TARGET_REQUIRED` | `non_json_target` | `schema_fail` | JSON operation on non-JSON target |
| `EXE_JSON_EXISTING_INVALID` | `non_json_existing` | `exec_fail` | Existing target has invalid JSON |
| `EXE_JSON_OBJECT_REQUIRED` | `non_object_json` | `schema_fail` | Object expected for merge |
| `EXE_READ_FAILED` | `read_failed` | `infra_fail` | Read I/O failure |
| `EXE_WRITE_FAILED` | `write_failed` | `infra_fail` | Write I/O failure |
| `EXE_DELETE_FAILED` | `delete_failed` | `infra_fail` | Delete I/O failure |

## Failure classes for queue policy

- `schema_fail`: malformed work-order / unsupported config (usually non-retriable without edit)
- `exec_fail`: target/data state issue (limited retriable, depends on context)
- `gate_fail`: validator or governance gate denies promote/advance
- `infra_fail`: transient infra/runtime issues (network/fs/runtime), retriable with higher budget
