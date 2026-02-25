# Current State Snapshot（naonao-content-ops）

## 当前目标（短期）
- 将 iter8-minpatch 作为 candidate 管理，进行稳定性复跑与扩样验证；同时落地技术顾问/硬验证器分层，缓解上下文爆炸与卡死风险。

## 已知状态（截至当前）
- 双根目录协作已跑通（openclaw / naonao_project）
- contracts 已建立：correction-event / rule-registry / work-order / execution-report
- feedback-router 已具备结构化纠错链路（diff -> 归因 -> correction event）
- execution-report schema 已兼容 meta / TEST / detail_phase
- baseline guard 已启用（低于基线不得晋升）
- 生产基线锁定：iter6
- iter7 已 rejected（73.33 < 83.33）
- iter8-minpatch（测试分支）回归结果：100.0（issue_class/core_tag/root_cause = 3/3）
- iter8 修复重点：factual_risk 门槛 / human_likeness 优先门 / tie-break 稳定 / span_note 编辑意图优先
- iter8 未覆盖生产基线（iter6 仍锁定）

## 当前风险
1. 回归样本仍偏少（固定3例）
2. 存在非确定性波动风险（iter6->iter7 无 skill 改动却退化）
3. 曾出现会话卡死（重复索样本），需补反卡死机制

## 当前建议下一步（Top 3）
1. 将 iter8-minpatch 记录为 candidate（不替换 baseline）
2. 对固定3例进行稳定性复跑 x3，输出一致性报告
3. 扩展回归样本到 8~12 例（含真实 factual_risk 边界样本）

## 关键路径
- reports/correction-regression-run-20260226-real-packe-iter8-minpatch.json
- reports/correction-regression-error-analysis-iter8.json
- docs/correction-regression-scoring.md
- reports/correction-regression-baseline-current.json
