# 闹闹内容系统纠错分类词典（Correction Taxonomy）

## 目标
统一“人工改稿 -> 结构化纠错事件 -> 规则候选”的分类口径，减少不同 agent / 人工审稿的标签漂移。

## 使用原则
1. 先看改前/改后差异，再打标签
2. 先打一级类目（issue_class），再打二级标签（issue_tags）
3. 标签必须有证据片段（来自 diff_segments）
4. 一个纠错事件可有多个标签，但建议 1~3 个
5. 根因层（root_cause_layer）与问题标签分开判断，不要混在一起

---

## 一级类目（issue_class）

### 1. human_likeness（人味）
用于描述文案像模板生成、像机器拼接、像口号堆砌而不自然。

常见信号：
- 引号过多
- 套话/模板腔
- 情绪词用力过猛，不像真实表达
- 句式重复，像批量生成

### 2. tone_consistency（语气一致性）
用于描述前后态度、角色口吻、表达立场不一致。

常见信号：
- 前文谨慎，后文突然强硬
- 同一段内“理性解释”和“强情绪命令”冲突
- 像换了一个人在说话

### 3. logic_closure（逻辑闭环）
用于描述叙事、论证、结构上的跳步与断裂。

常见信号：
- 没头没脑
- 缺过渡
- 结论出现太早
- 话题跳跃
- 只给做法，不给推理链路

### 4. mechanism_explanation（原理解释充分度）
用于描述“结论/风险/建议”背后的机制解释不足。

常见信号：
- 只说风险，不说原因
- 只说要做什么，不讲为什么
- 用户无法建立理解，导致 CTA 生硬

### 5. cta_coordination（行动建议衔接）
用于描述行动建议（CTA）的时机、语气、衔接不协调。

常见信号：
- 风险段刚结束就立刻硬命令
- 尚未建立理解就要求行动
- CTA 与上文逻辑未打通

### 6. factual_risk（事实风险）
用于描述事实表述可能不稳、前后矛盾或缺少依据。

（当前阶段可低优先级）

### 7. compliance_risk（合规风险）
用于描述平台/广告/医疗等表述风险。

（当前阶段可低优先级）

### 8. other（其他）
无法归类时临时使用，必须附原因说明。

---

## 二级标签（issue_tags）

### human_likeness
- `quote_overuse`：引号滥用，影响自然表达
- `template_voice`：模板腔/像AI套话
- `emotion_overdrive`：情绪过冲、表达过满

### tone_consistency
- `attitude_flip`：态度前后翻转
- `persona_shift`：人设口吻漂移

### logic_closure
- `missing_bridge`：缺少过渡句/承接句
- `premature_cta`：行动建议出现过早
- `incomplete_reasoning`：论证链不完整
- `topic_jump`：话题跳跃过快

### mechanism_explanation
- `no_mechanism_explained`：只给结论没讲原理
- `risk_without_cause`：只讲风险没讲成因

### cta_coordination
- `hard_command_after_warning`：风险段后直接硬指令
- `cta_without_readiness`：用户理解尚未建立就催行动

### 兜底
- `other`：无法归入现有标签（必须写 evidence_notes 说明）

---

## 根因层（root_cause_layer）判定口径
- `requirement_problem`：需求本身没讲清，导致生成偏航
- `template_problem`：模板结构导致固定错误（如 CTA 提前）
- `rule_problem`：规则本身缺失/冲突/误导
- `workflow_problem`：流程缺环节（如没做逻辑审稿）
- `skill_boundary_problem`：某 skill 做了不该做的判断或越权
- `input_data_problem`：背景信息不足、事实输入不完整
- `unknown`：暂时无法判断（需补信息）

> 注意：根因层是“为什么会犯错”，不是“错长什么样”。

---

## 常见误判提醒（非常重要）
1. `premature_cta` ≠ 一定是 `cta_coordination`
- 如果根因是模板固定结构，问题标签可仍是 `premature_cta`，但 root cause 应判 `template_problem`
2. `template_voice` ≠ 一定是 prompt 太差
- 也可能是规则写得过于抽象，导致生成只能套话（`rule_problem`）
3. `no_mechanism_explained` 不等于“篇幅不够”
- 核心是缺机制解释，不是字数多少
4. 一个事件不要贴太多标签
- 优先抓最影响可读性和转化的一两个问题

---

## 标注优先级建议（当前业务阶段）
优先捕捉：
1. `template_voice`
2. `quote_overuse`
3. `missing_bridge`
4. `premature_cta`
5. `no_mechanism_explained`
6. `hard_command_after_warning`

原因：这些最直接影响“像不像人写的”和“读者是否愿意继续看/相信/行动”。
