# 路由映射表（Execution Engineer Routing Map）

用途：

- 把“问题类型 -> 对应处理技能/模板/输出模式”映射清楚
- 也用于后续接入项目内现有 skills 时做路由参考

---

## 一级路由（问题类型）

### 1. 需求不清晰 / 想法很散

- 首选技能：requirement-shaper
- 输出模板：需求澄清单模板
- 后续可能接：task-architect / patch-spec-writer

### 2. 需要落地实现（新建或改文件）

- 首选技能：patch-spec-writer
- 辅助技能：task-architect
- 输出模板：工程执行单模板 + 验收清单模板

### 3. 结果不好用 / 跑偏 / 复杂度失控

- 首选技能：debug-triage
- 辅助技能：requirement-shaper（若需求本身不清）
- 输出模板：调试定位单模板

### 4. 上下文太长 / 需要换文本框

- 首选技能：context-handoff-builder
- 输出模板：上下文交接包模板

### 5. 规则冲突 / 规则膨胀 / 停用恢复

- 首选技能：rule-governance
- 输出模板：规则变更单模板

### 6. 需要判断是否复用已有 skill

- 首选技能：skill-dispatch-planner
- 输出模板：工程执行单模板（含复用方案）

---

## 二级路由（输出对象）

### 面向用户自己看

- 优先：结论 + 原因 + 下一步最省事操作

### 面向 OpenClaw 执行

- 必须：路径 + 改什么 + 怎么改 + 验收标准

### 面向其他 Agent（例如项目内）

- 必须：目标 Agent + 文件 + 改动类型 + 建议内容 + 不要改的部分
