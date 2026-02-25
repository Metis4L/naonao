# Rule Conflict Policy

## 1) 冲突定义
- contradiction: 规则结论相反，不能同时成立
- overlap: 规则覆盖高度重叠，导致重复执行
- scope_mismatch: 规则作用域放错层（模板/skill/全局）
- ambiguity: 描述不清造成执行分歧
- duplicate: 同义重复规则

## 2) 风险等级
- high: 直接导致输出方向错误或严重风格漂移
- medium: 局部冲突，影响稳定性
- low: 轻微重复或表达冗余

## 3) 处理动作
- merge
- add_condition
- reprioritize
- deprecate
- reject_candidate

## 4) 优先级规则
1. 平台安全规则 > 全局写作规则 > 项目规则 > 模板细节
2. 明确规则 > 模糊规则
3. 新证据充分规则 > 旧无证据规则

## 5) 回滚策略
- 高风险变更默认可回滚
- 先停用观察，再永久删除
- 回滚必须附带触发证据与影响范围
