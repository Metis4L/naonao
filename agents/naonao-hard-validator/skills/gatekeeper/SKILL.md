# SKILL: gatekeeper

## 目标
执行统一门禁校验：合同校验 + 执行报告校验 + 回归门禁 + 晋升门禁。

## 输入
- mode: contract | execution_report | regression_gate | promotion_gate
- artifacts:
- schema_path
- report_path
- baseline_record
- scoring_policy
- candidate_info
- thresholds（可选）

## 输出
- decision: pass | fail | conditional_pass
- reasons[]（逐条）
- evidence_refs[]（路径）
- suggested_fixes[]（最小修复）
- next_action

## 强制规则
- 若命中 baseline guard（低于基线），必须 fail
- 若 schema 漂移导致报告不可验证，必须 fail（或 conditional_pass + 明确补 schema）
- 不因“看起来不错”跳过门禁

## 验收标准
- 用户能据此直接决定：修补 / 重跑 / 拒绝 / 候选保留
