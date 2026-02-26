# Correction Regression Cases

## case_id: reg_001_human_likeness
- 改前稿："“完美猫粮”这就是答案，你直接冲。"
- 改后稿："这款在蛋白来源上更稳，但先看你家猫的适配反应。"
- 期望 issue_class：human_likeness
- 期望 issue_tags：quote_overuse, template_voice
- 期望 root_cause_layer：rule_problem
- 允许偏差：issue_tags 允许替换 1 个为 emotion_overdrive

## case_id: reg_002_logic_closure
- 改前稿："有风险，马上换粮。"
- 改后稿："风险点在矿物平衡，先观察便便和食欲，再决定是否换粮。"
- 期望 issue_class：logic_closure
- 期望 issue_tags：missing_bridge, premature_cta
- 期望 root_cause_layer：template_problem
- 允许偏差：issue_tags 允许 missing_bridge 与 incomplete_reasoning 互替

## case_id: reg_003_cta_coordination
- 改前稿："看完这些风险你必须现在就下单。"
- 改后稿："先确认是否命中对应信号，再决定是否调整方案。"
- 期望 issue_class：cta_coordination
- 期望 issue_tags：premature_cta, hard_command_after_warning
- 期望 root_cause_layer：requirement_problem
- 允许偏差：issue_tags 允许 cta_without_readiness 替代其中 1 个
