# Archive — README

All files in this folder are retired originals.  
They have been superseded by the restructured pipeline in `scripts/`.  
**Do not delete** — these files preserve the PhD analysis history and Git lineage.

---

## Retirement table

| File | Retired date | Replaced by | Reason |
|---|---|---|---|
| `01_Crops.Rmd` | 2026-05-03 | `clean/crops.R` (plot + crop cleaning), `clean/destinations.R` (crop disposition merge) | Restructured into clean pipeline script; Rmd format replaced with plain `.R` |
| `01_Recall.R` | 2026-05-03 | `clean/recall.R` | Consolidated into standard clean/ format; unit conversion logic preserved |
| `01b_Yield_gap.Rmd` | 2026-05-03 | Cleaning → `clean/crops.R` (plot_details); Imputation → `impute/yield_gap.R` | Split: mechanical cleaning separated from GYGA-based imputation |
| `02_Ag_produce.Rmd` | 2026-05-03 | `clean/ag_produce.R` | Consolidated into standard clean/ format |
| `03_Animals.Rmd` | 2026-05-03 | Cleaning → `clean/animals.R`; Feed imputation → `impute/animals.R` | Split: mechanical cleaning separated from FAO feed assumption imputation |
| `04_Animal_products.Rmd` | 2026-05-03 | `clean/animal_products.R` | Consolidated into standard clean/ format; egg consumption allocation flagged for stage 3 |
| `04_Milk.Rmd` | 2026-05-03 | `clean/milk.R` | Consolidated into standard clean/ format |
| `05_Destinations.Rmd` | 2026-05-03 | `clean/destinations.R` | Crop/tree disposition and residue estimation consolidated |
| `05_mergeagproducts.Rmd` | 2026-05-03 | Stage 3 (`03_build_households.R`, not yet created) | Merge logic belongs in household build stage; contents need manual review |
| `06.1_Survey_weighting.R` | 2026-05-03 | Pending — see note below | ⚠️ One canonical weighting script needed: review this vs `0x_Weighting.R` before stage 3 |
| `06_Summary.Rmd` | 2026-05-03 | Stage 5–8 (not yet created) | Summary/results script; contents need manual review for stages 5–8 |
| `06a_Residue.Rmd` | 2026-05-03 | `clean/destinations.R` (Section 4) | Residue estimation logic absorbed into destinations cleaning script |
| `0x_Weighting.R` | 2026-05-03 | Pending — see note below | ⚠️ One canonical weighting script needed: review this vs `06.1_Survey_weighting.R` before stage 3 |
| `99_C3a.Rmd` | 2026-05-03 | Stage 5–8 (not yet created) | Results assembly script; contents need manual review for stages 5–8 |
| `99_final.R` | 2026-05-03 | `00_run_pipeline.R` | Old pipeline runner (used `knitr::purl` pattern); replaced by `source()` pipeline |
| `animal_products_2.Rmd` | 2026-05-03 | `clean/animal_products.R` | Duplicate of `04_Animal_products.Rmd` — version number in filename anti-pattern; superseded |
| `xx_results.Rmd` | 2026-05-03 | Stage 8 (`08_outputs.R`, not yet created) | Results reporting script; contents need manual review for stage 8 |
| `01_load_data.R` | 2026-05-03 | `01_load_raw.R` | Empty stub; replaced by fully implemented loader |

---

## Notes on survey weighting

Two scripts cover survey weighting:

- `06.1_Survey_weighting.R` — adjusted weighting script that redistributes cluster weights for excluded households
- `0x_Weighting.R` — appears to be an earlier version of the same logic

**Before stage 3**: one canonical `weighting/survey_weights.R` script must be created.  
Steps:
1. Run both scripts side by side on the same input data
2. Compare outputs: do the derived weights (`weight_adj`) agree?
3. Identify which script has the more complete/correct logic
4. Merge the two into a single `scripts/weighting/survey_weights.R`

Until then, both files are archived here and weighting should not be applied to pipeline outputs.

---

## Notes on scripts flagged for manual review

The following scripts contain logic that could not be cleanly mapped to the new pipeline stages.  
Their contents need manual review before stages 5–9 are implemented:

| File | What to look for |
|---|---|
| `99_C3a.Rmd` | Results assembly: household-level MFA totals, exclusion summary, weight application. Likely feeds into stage 5 (`05_mfa_input.R`) and stage 8 (`08_outputs.R`). |
| `xx_results.Rmd` | Reporting tables and figures for PhD chapter 3a. Review for reuse in stage 8 (`08_outputs.R`). Uses `hhs_3a.csv` — confirm this is produced by `99_C3a.Rmd`. |
| `06_Summary.Rmd` | Loads final mass outputs and produces overview tables. Review for reuse in stage 8. Contains `zones` lookup for regional disaggregation — move to shared reference when regional analysis is implemented. |
| `05_mergeagproducts.Rmd` | Crops + ag_produce merge with manual audit log. Review for reuse in stage 3 (`03_build_households.R`). Note: `8659-001` manual fix in this script conflicts with same fix in `clean/destinations.R` — resolve before stage 3. |
