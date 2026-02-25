# Sample Expansion Plan — iter8-minpatch candidate

## Goal
Expand validation set from fixed 3 to 8~12 samples (with factual_risk boundary coverage) before any promotion decision.

## Required mix (minimum)
- 3 x human_likeness-oriented rewrites
- 2 x logic_closure-oriented rewrites
- 2 x cta_coordination-oriented rewrites
- 2 x factual_risk boundary cases (one true factual correction, one style-only false positive guard)
- + optional 1~3 mixed cases

## Acceptance gates
- total score >= 83.33
- issue_class hit >= 80%
- core_tag hit >= 80%
- no regression on reg_001/reg_002/reg_003
- baseline remains iter6 until user approval

## Artifacts to produce
- reports/correction-regression-run-20260226-iter8-expanded.json
- reports/correction-regression-error-analysis-iter8-expanded.json
- reports/hard-validator-gate-iter8-expanded.json

## Notes
- This is candidate validation only.
- No baseline promotion write is allowed in this phase.
