# Flags Review Log — Project 01

Updated after splitting crop logic into `clean/crops.R` and `impute/crops.R`. This version updates the crop-related assumption and exclusion flags to match the current script structure and preserves the existing note style from the working log. [cite:59][cite:122]

## Crop script split

| ID | Clean script | Impute script | Description | Value/Rule | Action needed |
|---|---|---|---|---|---|
| A02 | `clean/crops.R` | — | `gps_area == 0` recoded to `NA` | LSMS team recommendation; zero GPS treated as unreliable | Confirm this remains a standardisation rule rather than an imputation step. |
| A03 | `clean/crops.R` | — | GPS preferred over farmer area estimate for `plotsize` | `plotsize = gps_area_ha` where available, else `area_ha` | Confirm against LSMS-ISA literature on area measurement bias. |
| A04 | `clean/crops.R` | `impute/crops.R` | `area_harvested_alt` definition retained in clean; imputation uses harvested area as fallback for missing planted area | In clean: `area_harvested_ha / area_ha * plotsize`; in impute: `area_planted_ha_imp = area_harvested_ha` when `area_planted` missing and plot exists | Review divergence between farmer and GPS estimates; profile imputed cases separately. |
| A05 | `clean/crops.R` | `impute/crops.R` | Harvested-area candidates retained in clean; `total_harvest` moved to impute | In clean: candidate fields only; in impute: `total_harvest = harvest_remain + quant_harvest` | Sensitivity run with `total_harvest = quant_harvest` only. |

## Crop exclusion and review flags

| ID | Script | Reason | Type | Action needed |
|---|---|---|---|---|
| E01 | `clean/crops.R` | Harvest values set to `0` when `harvested == "no"` | Structural zero / missing data | Profile included vs flagged households by region, land size, and wealth. |
| E02 | `clean/crops.R` | `area_planted` missing on observed plot records is now flagged, not replaced, during cleaning | Missing data | Review flagged household-crop records; imputation now happens in `impute/crops.R`. |
| E03 | `clean/crops.R` | `ag3b_01b == 2` filters short-season plot-detail rows kept for analysis | Inclusion rule / codebook-dependent | Confirm codebook meaning of `ag3b_01b == 2` before Stage 4. |
| E03.1 | `clean/crops.R` | `area_harvested_com > plotsize` | Plausibility flag | Review with subject-matter judgement before treating as exclusion. |
| E03.2 | `clean/crops.R` | Blank or missing `plotnum` in short-season plot details | Missing identifier | Profile frequency and determine whether joins are affected downstream. |
| E03.3 | `clean/crops.R` | Short-season rows with `ag3b_01b != 2` or missing | Inclusion-rule audit flag | Keep count in audit log; check whether filtered rows show systematic patterns. |

## Crop internal data-quality flags

| ID | Script | Description | Type | Action needed |
|---|---|---|---|---|
| F01 | `clean/crops.R` | `flag_harvest_contradiction`: `harvested == "no"` but `quant_harvest` recorded | Enumerator contradiction | Profile by crop and season; decide whether to exclude or manually inspect. |
| F02 | `clean/crops.R` | `flag_harvest_quantity_missing`: `harvested == "yes"` but `quant_harvest` is `NA` | Missing quantity | Consider imputation rule only after profiling count and pattern. |
| F03 | `clean/crops.R` | `flag_harvest_missing`: `harvested` missing while plot and crop are present | Missing participation status | Review whether these are partial interviews or item non-response. |
| F04 | `clean/crops.R` | `flag_harvest_remain_missing`: `harvested == "yes"` but `harvest_remain` is `NA` | Missing remainder estimate | Confirm whether true missingness should remain `NA` or be imputed later. |
| F05 | `clean/crops.R` | `flag_area_planted_missing`: `area_planted` missing on non-missing `plotnum` | Missing planted fraction | Used to separate clean-stage review from imputation-stage replacement. |
| F06 | `clean/crops.R` | `flag_plotnum_missing`: crop record missing `plotnum` | Missing identifier | Check join loss against plot roster and destination files. |
| F07 | `clean/crops.R` | `flag_area_harvested_gt_plotsize`: harvested-area candidate exceeds `plotsize` | Plausibility flag | Review before exclusion; compare with area source (`gps` vs farmer estimate). |
| F08 | `clean/crops.R` | `flag_quant_harvest_missing`: `quant_harvest` missing with observed `plotnum` | Missing quantity | Consider whether these cases overlap fully with F02. |
| F09 | `impute/crops.R` | `flag_area_planted_ha_imputed`: `area_planted_ha` replaced using `area_harvested_ha` | Imputation applied | Report count separately from raw missingness. |
| F10 | `impute/crops.R` | `flag_area_harvested_gt_plotsize_imp`: imputed/composite harvested area exceeds `plotsize` | Post-imputation plausibility flag | Compare with pre-imputation F07 to see whether imputation increases implausible cases. |

## Resolved crop changes

| Script | Was | Resolution |
|---|---|---|
| `clean/crops.R` | `area_planted_ha` missing values replaced directly in cleaning | Moved to `impute/crops.R` so value-changing logic is separated from cleaning. |
| `clean/crops.R` | `total_harvest` created in cleaning | Moved to `impute/crops.R` because it is an inferred composite field. |
| `clean/crops.R` | Mixed flag naming (`mismatch`, `missing_quant`, generic counters) | Standardised to `flag_*` and `n_flag_*` naming. |
| `clean/crops.R` | Short-season message implied duplication across seasons | Message now states exact rule: `ag3b_01b != 2` or missing. |
| `clean/crops.R` | Plot-detail filter had no explicit guard note | `stopifnot()` retained and filter meaning documented as codebook-dependent. |

## Priority decisions

| Priority | Item | Who |
|---|---|---|
| High | Confirm codebook meaning of `ag3b_01b == 2` for short-season plot details. | Codebook |
| High | Review harvest contradiction and missingness flags (`F01`–`F04`) before any imputation beyond current rules. | Data/code |
| Medium | Profile overlap between `F02` and `F08` to avoid duplicate handling of missing harvest quantity. | Data/code |
| Medium | Test whether `A04` increases `F10` relative to `F07`. | Data/code |
| Low | Decide whether `A02` and `A03` remain in `clean/` permanently or move to a documented standardisation layer. | Methods |

## Notes for audit script

- `05_exclusions_audit.R` should now treat crop review in two stages: raw cleaning flags from `clean/crops.R`, then imputation-applied flags from `impute/crops.R`. [cite:59][cite:122]
- For crops, profiling should distinguish three concepts: structural zero, raw missingness, and imputation-applied replacement. [cite:59][cite:131]
- Any README or methods note should describe `pc.rds` as the clean merged crop-plot file and `pc_imputed.rds` as the assumption-applied version. [cite:122][cite:131]
