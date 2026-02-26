# Promotion Packet (Draft) — iter8-minpatch

## 0) Decision Request
- Candidate: `iter8-minpatch`
- Current production baseline: `iter6` (locked)
- Requested decision: **Approve / Reject promotion to production baseline**

## 1) Metrics Summary
- Fixed-set regression x3: `100 / 100 / 100` (std=0.0)
- Shadow monitoring latest: `mean=100.0, std=0.0, n=4`
- Drift flags: `unexplained_regression=false`, `unstable_candidate=false`
- Baseline overwrite guard: `true` (no production overwrite)

## 2) Evidence
- `reports/correction-regression-stability-iter8-x3.json`
- `reports/correction-regression-shadow-monitoring.json`
- `handovers/iteration-ledger.json`
- `reports/hard-validator-gate-wo-ext-004.json`

## 3) Risk List (must be acknowledged)
1. Sample coverage still narrow (`n=4` shadow set) and may under-represent real distribution.
2. Historical non-determinism has occurred before (iter6 -> iter7 regression without explicit skill change).
3. External-source cases (e.g., anti-scrape inputs) still depend on fallback and may introduce variance.

## 4) Rollback Plan
If promoted and regression occurs:
1. Re-point baseline to `iter6` in baseline pointer/ledger.
2. Freeze candidate writes (`shadow only`) and collect failure traces.
3. Run stability matrix + expanded samples before re-approval.

## 5) Approval Block
- [ ] Approve promotion to production baseline
- [ ] Reject (keep iter6 locked, continue shadow monitoring)
- Approved by: __________
- Time: __________
- Notes: __________
