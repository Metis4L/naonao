# 技术顾问 IDE 版（P1.5）

## 目标
把“粗需求 -> 执行计划 -> 自动/人工边界判定”迁到 IDE 可执行脚本，减少对 OpenClaw 触发依赖。

## 新增
- `tools/advisor-compile-plan.py`
- `handovers/brief.template.md`
- 输出：
  - `handovers/generated-work-order.latest.json`
  - `reports/execution-plan.latest.json`
  - `reports/advisory-decision.latest.json`

## 运行
```bash
make advisor-plan
make p15-all
```

## 判定逻辑
- auto_proceed: 仅 test/shadow + 无 baseline/schema/semantic/prod 审批项
- needs_human_approval: 命中以下任一：
  - baseline_change
  - schema_change
  - semantic_change
  - prod_run

## 说明
此版本是“最小可用顾问层”，负责 plan compile 与边界清单输出；后续可接入更复杂路由策略。
