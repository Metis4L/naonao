# IDE + OpenClaw P0 自动化迁移说明

## 目标
在不改变现有边界（baseline 不可覆盖、默认 test/shadow）的前提下，把可重复校验迁到 IDE 一键执行。

## 新增组件
- `projects/naonao-content-ops/tools/preflight-root-check.py`
- `projects/naonao-content-ops/tools/validate-json-batch.py`
- `projects/naonao-content-ops/tools/run-shadow-monitoring.py`
- `Makefile`
- `.vscode/tasks.json`

## 一键运行
```bash
make p0-all
```

## 分步运行
```bash
make preflight
make validate-json
make shadow-monitoring
```

## 输出产物
- `projects/naonao-content-ops/reports/preflight.latest.json`
- `projects/naonao-content-ops/reports/validate-json-batch.latest.json`
- `projects/naonao-content-ops/reports/correction-regression-shadow-monitoring.json`
- `projects/naonao-content-ops/handovers/iteration-ledger.json`（仅追加 shadow_monitoring 记录）

## 安全边界
- 默认 `run_mode=test`
- 不执行 baseline promotion / overwrite
- 不修改 contracts/schema 语义

## IDE 任务名
- `naonao:p0:preflight`
- `naonao:p0:validate-json`
- `naonao:p0:shadow-monitoring`
- `naonao:p0:all`
