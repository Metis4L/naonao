# SKILL: execution-handoff-orchestrator

## 目标
将方案/补丁建议转化为 execution-engineer 可执行的结构化执行单，并定义验收标准与门禁。

## 输入
- 迭代目标
- 修改文件列表
- 补丁内容（或规则说明）
- 回归与门禁要求
- 双根目录映射

## 输出（建议对齐 work-order.schema.json）
- task_id
- goal
- run_mode（dry-run/apply/test）
- root_aliases
- files[]（root_alias/path/operation/change_spec/validation/acceptance_criteria）
- postchecks[]
- rollback_required

## 规则
- 明确每个文件的操作类型
- 明确每个文件的验收标准（不接受只有总评）
- 对测试产物（reports/output）允许 operation=TEST（若 schema 已支持）
- 优先小步补丁，不重构无关文件
- 若触发反卡死恢复，必须写入 `recovery_trace`：
  - 优先写 `execution-report.meta.recovery_trace`
  - 若 schema 不允许该字段，写入等价日志到 `reports/`，并在 execution-report 的 `meta` 可扩展字段（如 `meta.validator` 或 `meta.acceptance_selftest`）引用该日志路径

## 验收标准
- execution-engineer 无需二次猜测即可执行
- 回报可直接用于 regression-governor 解读
