# ROUTING_MAP

## 总体路由策略
本 agent 为“控制面”，负责把任务路由到：
- 内部技能（需求塑形、迭代策略、上下文交接、卡死恢复、结果解读）
- execution-engineer（执行面）
- hard-validator（门禁面，可选）

不直接改文件。

---

## 路由入口类型

### A. 新需求 / 模糊目标
触发条件：
- 用户描述想做什么，但没有清晰边界/验收

路由：
1) requirement-shaping
2) iteration-strategist

输出：
- 需求收口
- 当前轮目标
- 执行单草案（如可执行）

### B. 执行结果回报（execution-report / 回归报告）
触发条件：
- 用户贴 execution-report JSON
- 用户贴评分、回归结果、错误分析

路由：
1) regression-governor
2) execution-handoff-orchestrator（如需下一轮）

输出：
- 结果解读（成功/退化/漂移）
- 最小修复方案
- 下一轮执行单

### C. 卡死 / 重复追问 / 状态混乱
触发条件：
- 重复要求同一输入
- “缺上下文无法继续”循环出现

路由：
1) deadlock-recovery-planner

输出：
- 恢复模式（analysis-only / awaiting_user_input）
- 最小恢复指令
- 若必要，生成新的上下文交接包

### D. 基线 / 候选晋升相关
触发条件：
- 提到 baseline、candidate、rejected、guard、晋升/拒绝

路由：
1) regression-governor
2) （可选）hard-validator handoff

输出：
- 晋升建议单 / 拒绝记录 / 稳定性复跑建议

### E. 工程交接 / 新会话恢复
触发条件：
- “开新 session”“交接”“恢复”“当前状态”

路由：
1) context-pack-curator

输出：
- 单页状态快照
- 迭代台账更新
- 恢复命令建议

---

## 与 execution-engineer 的交接协议

### 输入（给 execution-engineer）
- 结构化执行单（建议对齐 work-order.schema.json）
- root_aliases
- 目标文件路径
- 操作类型（ADD/MODIFY/MERGE/DELETE/TEST）
- 验收标准
- run_mode（dry-run/apply/test）

### 输出（来自 execution-engineer）
- execution-report（建议对齐 execution-report.schema.json）
- file_results（逐文件）
- blocking_issues
- next_actions
- meta（可选，但需在 schema 定义内）

---

## 死循环恢复规则（必须）
如果检测到同一缺失字段被连续追问 >=2 次：
1. 停止重复追问
2. 输出当前状态摘要 + 阻塞项 + 可做部分（至少3项）
3. 进入 `awaiting_user_input` 或 `analysis_only`
4. 给出单行恢复命令模板
