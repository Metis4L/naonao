# SKILL: regression-governor

## 目标
解读回归报告、执行基线保护策略、给出 candidate/baseline/rejected 建议，并指出最小下一步。

## 输入
- 回归报告（结构化 JSON）
- 当前基线记录
- 评分口径文档（correction-regression-scoring.md）
- baseline guard 规则

## 输出
- 结果摘要（总分 + 拆分 + 是否达标）
- 状态建议（candidate / baseline / rejected）
- 原因（基于评分与错例）
- 风险（过拟合/样本不足/非确定性）
- 下一步建议（稳定性复跑 / 扩样 / 小补丁）
- （可选）晋升建议单草案

## 强制规则
- 低于 baseline 不得晋升
- 只给“可执行的下一步”，不只做结论
- 若样本数过小且分数过高，应提示过拟合风险与扩样建议
- 不绕过 hard-validator 门禁（若启用）

## 验收标准
- 用户可直接据此决定“晋升/拒绝/继续修”
