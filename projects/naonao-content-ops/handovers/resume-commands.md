# Resume Commands（恢复命令手册）

## 1. 新会话恢复（只分析，不执行，不要样本）
resume naonao-content-ops analysis-only:
- 使用 handovers/current-state.md
- 输出：当前目标 / 已知状态 / 下一步Top3 / 风险
- 禁止重复索要样本

## 2. 继续 iter8 候选验证（稳定性复跑）
resume iter8 candidate validation:
- 目标：固定3例复跑 x3
- 输出：一致性报告 + 是否保持 candidate

## 3. 带样本恢复（纠错归因调试）
resume regression debug with sample: obs_001｜改前：...｜改后：...

## 4. 卡死恢复（当前会话重复追问）
停止重复追问。进入无样本恢复模式：
- 先输出任务目标 / 已知状态 / 阻塞项 / 当前可做下一步（至少3项）
- 若仍缺输入，最多提示一次最小格式后进入 awaiting_user_input

## 5. 候选晋升前门禁校验
run hard-validator promotion gate:
- candidate_iter:
- baseline_iter:
- reports:
- scoring_policy:
