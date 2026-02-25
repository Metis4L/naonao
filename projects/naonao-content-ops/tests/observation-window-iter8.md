# Observation Window — iter8 baseline

目标：用真实业务样本验证 iter8 在非回归样本上的稳定性。

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
- 是否可执行（是/否）
- 是否有明显误判（是/否）
- 备注

## 通过标准（建议）
- issue_class 命中率 >= 80%
- core_tag 命中率 >= 80%
- root_cause 合理率 >= 70%
- 无系统性偏差（同类样本连续误判 >= 3）

## 结束动作
- 达标：保持 iter8 baseline
- 不达标：开 iter9 最小修复补丁，仅修单点偏差
