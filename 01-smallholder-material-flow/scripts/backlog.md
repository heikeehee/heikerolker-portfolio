# Project 01 — Backlog

Items documented here are known limitations or planned improvements.
None are on the critical path for the current portfolio release.
This file is intentionally public — transparent documentation of limitations
is standard practice in rigorous analytical work.

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

## B05 — Processed crops extraction rate sensitivity
**Priority:** Medium
**Affects:** Project 01 mass balance, MFA input variables
Extraction rates (e.g. 72% flour yield from maize) are literature-derived and unverifiable
from LSMS-ISA survey data. Run mass balance and MFA with ±10% rate variation.
See impute/processed_crops.R for full rate table.

## B06 — Unclassified items in item_groups.csv
**Priority:** Low
**Affects:** Project 01 MFA, Project 03 clustering
~59 items have no MFA group assignment. Confirm which appear in households.rds.
Assign groups or document exclusion rationale for each.
See FLAGS_REVIEW.md for the full list of unclassified items.

## B07 — item_groups.csv master file structure
**Priority:** Low (post-portfolio)
Single master reference file across all projects with project-specific inclusion flags.
See data/reference/item_groups_README.md for proposed structure.

## B08 — Feed dry matter conversion
**Priority:** Low
**Affects:** Project 01 Sankey, MFA input feed variables
Feed quantities in Sankey = feed_crops_kg_fresh + feed_liveweight_kg_DM (mixed units).
Correction requires per-crop DM conversion factors and crop-level feed recording.
LSMS-ISA data does not support this for most households.
Do not cite absolute feed totals as dry matter equivalents.
Revisit if future survey waves record which crops are fed to animals.
