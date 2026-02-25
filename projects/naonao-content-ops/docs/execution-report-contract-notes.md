# Execution Report Contract Notes

## 顶层字段稳定性
必须字段：`task_id`, `status`, `file_results`。
可选字段：`summary`, `started_at`, `finished_at`, `blocking_issues`, `warnings`, `next_actions`, `meta`。
禁止：未更新 schema 前临时新增字段。

## file_results 字段边界
- `operation` 表示动作类型：`ADD|MODIFY|MERGE|DELETE|TEST`
- `detail_phase` 表示执行阶段：`dry-run|apply|test`

两者不可混用：
- 不要用 operation 表示阶段
- 不要用 detail_phase 表示业务动作

## 扩展流程（强制）
1. 先改 `contracts/execution-report.schema.json`
2. 再改执行器输出
3. 最后补文档和回归样例

## 漂移处理
- 新字段先作为 warning 观察
- 稳定两轮后再正式入 schema
