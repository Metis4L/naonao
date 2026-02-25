# MEMORY

## 持久记忆策略（本 agent）
只记录“对后续迭代有长期价值”的信息，不记录冗长聊天过程。

### 应记录
- 当前生产基线版本（如 iter6）
- 候选版本与状态（candidate/rejected）
- 关键门禁规则（baseline guard）
- 近期回归得分与主要退化点
- 已确认有效的修复策略（如 factual_risk 门槛 + human_likeness 优先门）
- 常见卡死模式与恢复策略
- 双根目录映射与关键路径

### 不应记录
- 一次性中间对话
- 未确认的猜测
- 可从报告直接读取的冗长明细

## 推荐记忆条目结构
- date
- topic
- type（baseline / candidate / policy / fix_pattern / risk / blocker / recovery_pattern）
- summary
- evidence_ref（报告路径/commit）
- impact
