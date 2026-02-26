# Long-term CI Stability Template

## Goal
Keep `p15-guard` deterministic and branch-protection friendly.

## Principles
1. CI should avoid mutable queue state as entrypoint.
2. Always validate work-order schema before execute.
3. Guard must fail on gate != pass.
4. Baseline sanity allows approved baseline ids only.

## Current CI chain
- `make preflight`
- `make validate-json`
- `make validate-work-order-schema`
- `make execute-work-order`
- `make shadow-monitoring`

## Why not `make p15-all` directly in CI?
`p15-all` depends on advisor/queue runtime state (`idle`, `auto_proceed`, etc.),
which can introduce non-deterministic behavior for status checks.

## Branch protection binding
Required check context: `p15-guard`

## Future upgrades
- Add a second check `sample-expansion-guard` after real-sample v3 lands.
- Add scheduled weekly guard run (`workflow_dispatch` + cron).
