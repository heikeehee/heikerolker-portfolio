# Project 01 — Backlog

Items documented here are known limitations or improvements.
None are on the critical path. Revisit after portfolio is complete.

## B01 — Imputation sensitivity analysis
**Priority:** High (methodological)
**Affects:** Projects 01, 02, 03
Exclusions currently stand as published in thesis. Known weak point.
When revisited:
- Profile excluded vs included households (05_exclusions_audit.R)
- Introduce imputation as sensitivity analysis (impute/ scripts)
- Re-run MFA with imputed dataset, compare factor scores
- Report whether conclusions change

## B02 — Structural zero classification audit
**Priority:** Medium
**Affects:** Project 01
na.rm = TRUE flags in 04_build_households.R not yet individually reviewed.
Each needs confirming as structural zero or missing data.

## B03 — Milk density assumption
**Priority:** Low
**Affects:** Project 01
Density of 1.03 kg/litre assumed — confirm against LSMS-ISA codebook or FAO conventions.

## B04 — Weighting scripts
**Priority:** Medium
Two weighting scripts archived (06.1_Survey_weighting.R, 0x_Weighting.R).
One canonical script needed. Review and consolidate before publishing final results.
