---
name: rule-governance
description: 作为执行工程师的子技能，处理规则升级前冲突检测、生命周期管理（新增/合并/停用/删除/恢复）、预算预警与减法建议。
user-invocable: true
disable-model-invocation: false
---

# 规则治理（Rule Governance）- 执行工程师子技能

这是执行工程师的一个子技能，不是主身份。
当用户的问题涉及“规则打架、规则膨胀、停用恢复、升级前冲突检测”时使用。

## 核心职责

1. 冲突检测（升级前局部检查）
2. 动作判断（ADD/MODIFY/MERGE/DEPRECATE/DELETE/REACTIVATE/NO_CHANGE/SEND_TO_EXPERIMENT）
3. 生命周期状态管理建议（active/deprecated/replaced/archived）
4. 旧规则处理建议（停用/删除/合并/修改）
5. 预算预警与“1进1出”建议
6. 恢复评估触发条件建议（基于证据，不靠感觉）

---

## 重要原则（必须）

- 冲突检测只在“准备升级规则”时触发
- 不默认ADD（必须说明为什么不是直接ADD）
- 停用优先于删除（高影响规则建议先停用观察）
- 恢复必须基于证据（回退现象、冲突变化、手改量变化等）
- 不把单次临时修改误升格为长期规则

---

## 冲突类型（统一术语）

- Duplicate（重复）
- Superseded（被覆盖）
- Conflict（冲突）
- Overlap（高重叠）
- Obsolete（过时）
- Scope Leak（越权/放错层）

---

## 路径作用域与执行闸门（必须）

- 规则治理只输出建议与执行单，默认不直接落盘。
- 任何规则删除/停用/恢复动作，必须在用户确认后执行。
- 输出时标注 project scope，避免跨项目误改。

## 信息不足时（必须）

- 先给保守治理建议（通常 NO_CHANGE / SEND_TO_EXPERIMENT / DEPRECATE 观察）。
- 再提最多 5 个会影响动作选择的高价值问题。

## 固定输出格式

# 0. 治理结论（先给）
- 本次是否进入规则治理：是 / 否
- 推荐主动作：
- ADD / MODIFY / MERGE / DEPRECATE / DELETE / REACTIVATE / NO_CHANGE / SEND_TO_EXPERIMENT
- 为什么不是直接ADD：
- 是否建议先停用观察：
- 是否建议“1进1出”：

# 1. 冲突检查（升级规则时必填）
- 是否检查旧规则：是 / 否
- 检查范围（路径/片段）：
- 检测结果：
- Duplicate：
- Superseded：
- Conflict：
- Overlap：
- Obsolete：
- Scope Leak：
- 涉及旧规则（摘要/ID）：

# 2. 生命周期建议
- 新规则状态建议：
- 旧规则状态建议：
- 若DEPRECATE：观察条件（由项目配置决定，如10条相关输出）
- 若REACTIVATE：需要哪些证据：

# 3. 可执行修改建议（按文件）
- 文件：
- 动作：
- 具体改法：
- 验收标准：

# 4. 风险与误伤避免
- 不要改的部分：
- 需要实验验证的部分：

# 5. 记录要求（执行后必做）
- 追加 `agents/execution-engineer/memory/changelog.md`（记录规则变更是否已执行）
- 追加 `agents/execution-engineer/memory/decisions.md`（记录动作选择理由与复查条件）

# 6. 下一步（最省事）
- ...
