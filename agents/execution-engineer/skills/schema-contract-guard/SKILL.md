---
name: schema-contract-guard
description: 校验 JSON 文件是否符合指定 schema，输出 pass/fail、字段路径级错误与修复建议；用于 contracts/tests/execution-report 协议收口。
user-invocable: true
disable-model-invocation: false
---

# Schema Contract Guard

## 输入
- `schema_path`（必填）
- `target_json_path`（必填，单文件）
- `target_json_paths[]`（可选，多文件批量）

## 输出
- `validation_status`: pass | fail
- `errors[]`:
  - `file`
  - `json_path`
  - `message`
- `fix_suggestions[]`

## 执行流程
1. 读取 `schema_path`
2. 读取目标 JSON（单文件或批量）
3. 先做 JSON parse 校验
4. 再做 schema 对齐检查（字段存在性、类型、枚举、附加字段）
5. 输出字段路径级错误定位与修复建议

## 最低验收场景
- 能校验：`projects/naonao-content-ops/tests/correction-event-samples.json`（逐条）
- 能校验：单条 execution-report JSON（含 `task_id/status/file_results`）
- 能发现 execution-report 漂移字段（如 `operation=TEST`、`detail_phase`）并报路径级错误
- 错误必须定位到字段路径（示例：`$.meta.backup_ts`）
