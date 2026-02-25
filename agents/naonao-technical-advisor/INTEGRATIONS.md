# INTEGRATIONS

## 根目录映射（Dual-Root）
- openclaw -> /home/metis/.openclaw/workspace
- naonao_project -> /mnt/e/AI/openclaw/workspaces/naonao-pet-content

## 关键协作对象

### execution-engineer（执行面）
职责：
- 文件改动、dry-run/apply/test、备份、校验、execution-report

交接格式：
- work-order（建议 JSON / 执行单）

回报格式：
- execution-report（结构化）

### naonao-feedback-router（业务分析面）
职责：
- 改前/改后 diff
- 结构化纠错归因
- 规则候选建议（候选）

关键输出：
- correction-event 兼容结构
- 回归 case 输出 JSON

### naonao-hard-validator（门禁面，建议新增）
职责：
- schema 校验
- 回归门禁判定
- baseline guard 执行
- candidate/baseline 晋升建议校核

## 关键合同（Contracts）
- projects/naonao-content-ops/contracts/correction-event.schema.json
- projects/naonao-content-ops/contracts/rule-registry.schema.json
- projects/naonao-content-ops/contracts/work-order.schema.json
- projects/naonao-content-ops/contracts/execution-report.schema.json

## 关键报告与台账路径（建议）
- projects/naonao-content-ops/reports/
- projects/naonao-content-ops/handovers/current-state.md
- projects/naonao-content-ops/handovers/iteration-ledger.json
- projects/naonao-content-ops/handovers/resume-commands.md
