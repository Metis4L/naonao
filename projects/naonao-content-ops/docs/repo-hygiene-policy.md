# Repo Hygiene Policy (naonao-content-ops)

## Goal
Reduce workspace noise and accidental operations via dry-run first, then audited cleanup.

## Archive Rules
- `*.bak*` -> move to `projects/naonao-content-ops/archive/bak/`
- temp reports `execution-report-*-latest*` and transient run artifacts -> move to `projects/naonao-content-ops/archive/reports/`
- python cache dirs `__pycache__/` -> remove

## Keep Whitelist
Never auto-move/delete:
- `projects/naonao-content-ops/contracts/**`
- `projects/naonao-content-ops/handovers/current-state.md`
- `projects/naonao-content-ops/handovers/iteration-ledger.json`
- `projects/naonao-content-ops/reports/correction-regression-baseline-current.json`
- `agents/**/auth*.json` (sensitive; manual handling only)

## Workflow
1. Run dry-run scanner and produce report.
2. Review report + whitelist diffs.
3. Execute cleanup script in apply mode (after approval).
4. Commit policy + report + moved artifacts index.
