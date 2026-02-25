# Observation Window — iter8 candidate（test branch only）

目标：在不触碰生产基线 iter6 的前提下，用真实样本验证 iter8 最小补丁稳定性。

## 观察范围
- 样本数：10 条（真实改前/改后）
- 内容类型：猫粮分析 / 行为学 / 新手养猫 / 热点（尽量覆盖）
- 平台：douyin/xiaohongshu/wechat（按实际）

## 每条记录字段
- sample_id
- issue_class
- issue_tags[]
- root_cause_layer
- editor_action_types[]
- issue_class_rationale（若有）
- patch_effect_observed（fixed/unchanged-ok/needs-followup）
- 是否可执行（是/否）
- 是否有明显误判（是/否）
- 备注

## 通过标准（硬门槛）
- 总分 >= 83.33（对齐 iter6 guard）
- reg_001 的 issue_class 维持修复
- reg_002 / reg_003 不回退
- issue_class 命中率 >= 80%
- core_tag 命中率 >= 80%
- root_cause 合理率 >= 70%
- 无系统性偏差（同类样本连续误判 >= 3）

## 结束动作
- 达标：标记为 `iter8_candidate_ready`（仅候选，待人工确认是否晋升）
- 不达标：iter8 自动 rejected（仅测试记录），继续最小修复
- 任意情况：生产基线保持 iter6，不覆盖
