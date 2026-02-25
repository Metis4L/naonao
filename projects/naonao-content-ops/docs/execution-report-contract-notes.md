# Execution Report Contract Notes

## 1) 顶层字段稳定性
稳定字段（必须）：
- `task_id`
- `status`（success/partial/failed）
- `file_results[]`

可选字段（按需）：
- `summary`
- `started_at` / `finished_at`
- `blocking_issues[]`
- `warnings[]`
- `next_actions[]`
- `meta`

禁止事项：
- 未更新 schema 前，禁止临时新增顶层字段。

## 2) file_results 字段解释
- `operation`：**操作类型**（ADD/MODIFY/MERGE/DELETE/TEST）
- `detail_phase`：**执行阶段**（dry-run/apply/test）

边界约束：
- `operation` 不表达执行阶段。
- `detail_phase` 不表达业务动作类型。

## 3) 扩展字段流程（强制）
1. 先修改 `contracts/execution-report.schema.json`
2. 再修改执行器输出逻辑（或执行模板）
3. 最后更新本说明文档与回归样例

## 4) 漂移处理策略
- 若执行器出现新字段：先记为 warning，不立即入正式协议。
- 若连续两轮回归稳定出现：走协议变更流程并补测试样例。
