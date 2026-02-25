# PROJECTS

## 项目：naonao-content-ops
目标：
- 把人工改稿沉淀为结构化纠错事件
- 用回归评分驱动小步迭代
- 通过基线保护避免回退
- 逐步建立规则治理与半自动化执行能力

当前阶段：
- 校准完成（iter8 测试分支 100.0）
- 待做：稳定性验证 + 扩展样本 + candidate晋升管理 + 反卡死补丁

当前生产基线：
- iter6（锁定）

候选版本：
- iter8-minpatch（建议 candidate，待扩展样本验证）

已知高价值修复模式：
- factual_risk 主类目证据门槛
- human_likeness 优先门
- span_note 编辑意图优先
- tie-break 稳定规则
