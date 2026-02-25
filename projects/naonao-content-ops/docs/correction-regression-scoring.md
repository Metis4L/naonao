# Correction Regression Scoring

## 评分目标
让每轮结构化归因结果可横向比较，避免主观口头判断。

## 指标与权重
- `issue_class_match`：30
- `core_tag_hit`：35
- `root_cause_match`：20
- `candidate_rule_usefulness`：15

总分 = 30*class + 35*tag + 20*root + 15*rule_usefulness
（各项按 0/1 或 0~1 归一化）

## 判定口径
### 1) issue_class_match
- 预测一级类目与期望一致记 1，否则 0。

### 2) core_tag_hit
- 期望核心标签命中至少 1 个记 1；全未命中记 0。
- 若是多标签任务，可按命中比例给分（0~1）。

### 3) root_cause_match
- 根因层完全一致记 1。
- 若在允许偏差列表内记 0.5。

### 4) candidate_rule_usefulness
- 候选规则可执行、非空泛、scope 明确记 1。
- 若仅抽象建议或重复候选，记 0~0.5。

## 回归通过建议阈值
- 单轮平均分 >= 0.70：可进入下一轮优化
- 单轮平均分 >= 0.80：可考虑小范围采纳
- 任一必测项连续两轮 < 0.60：触发最小修复补丁
