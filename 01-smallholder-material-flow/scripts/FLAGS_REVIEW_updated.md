# Flags Review Log — Project 01

Updated to match the revised crop workflow. In the current convention, cleaning scripts contain flags and harmless standardisations only, while imputation scripts hold value-changing assumptions. No crop item is treated as an exclusion at this stage; unresolved items remain flags until they can be imputed or explicitly justified later.

## Assumptions

| ID | Script | Type | Description | Action needed |
|---------------|---------------|---------------|---------------|---------------|
| A1 | `clean/crops.R` | Assumption | GPS readings of 0 are treated as missing. | Confirm this remains a standardisation rule and not an imputation. |
| A2 | `clean/crops.R` | Assumption | GPS area is preferred over farmer-reported area for `plotsize`. | Confirm against LSMS-ISA area-measurement guidance. |
| A3 | `clean/crops.R` | Assumption | `area_harvested_alt` is retained as a candidate proportional estimate. | Review whether it should remain diagnostic only. |
| A4 | `impute/crops.R` | Assumption | Missing `area_planted_ha` may be replaced using `area_harvested_ha`. | Profile affected records and keep count in the audit log. |
| A5 | `impute/crops.R` | Assumption | `total_harvest = harvest_remain + quant_harvest`. | Keep sensitivity check if needed. |
| A1 | impute/animal_products.R | Assumption | Gateway “no” responses imply structural zeros in imputation.                                       | Keep explicit in impute. |
| A2 | impute/animal_products.R | Assumption | Hides allocation is based on slaughter-linked support, not on animals that died from other causes. | Review and document.     |
| A3 | impute/animal_products.R | Assumption | Egg feed allocation uses the poultry feed crosswalk.                                               | Keep explicit in impute. |
| A4 | impute/animal_products.R | Assumption | Missing feed splits may be defaulted only in imputation and should remain reviewable.              | Keep explicit in impute. |
| A1 | impute/milk.R | Assumption | Missing average milk production may be filled using reported disposition values. | Document explicitly.             |
| A2 | impute/milk.R | Assumption | Reported processed < psold is corrected by replacing processed with psold.       | Keep as a logged rule.           |
| A3 | impute/milk.R | Assumption | Milk uncertainty is approximated using range/4.                                  | Document and justify.            |
| A4 | impute/milk.R | Assumption | Feed requirement factors are applied uniformly within ruminant groups.           | Keep explicit.                   |
| A5 | impute/milk.R | Assumption | Milk density is 1.03 kg/litre.                                                   | Confirm against source standard. |
## Flags

| ID | Script | Type | Description | Action needed |
|---------------|---------------|---------------|---------------|---------------|
| F1 | `clean/crops.R` | Flag | `harvested == "no"` but `quant_harvest` is recorded. | Profile by crop and season; decide whether a later repair is defensible. |
| F2 | `clean/crops.R` | Flag | `harvested == "yes"` but `quant_harvest` is missing. | Review for enumerator error versus later imputation. |
| F3 | `clean/crops.R` | Flag | `harvested` response is missing on an observed crop record. | Profile missingness pattern before any repair. |
| F4 | `clean/crops.R` | Flag | `harvest_remain` missing when `harvested == "yes"`. | Check whether this is separate from F2 or fully overlapping. |
| F5 | `clean/crops.R` | Flag | `area_planted` missing on an observed plot record. | Hand off to imputation if a defensible fallback exists. |
| F6 | `clean/crops.R` | Flag | `plotnum` missing on crop record. | Check join loss and downstream matching impact. |
| F7 | `clean/crops.R` | Flag | `area_harvested_com > plotsize`. | Review for measurement mismatch or implausible record. |
| F8 | `clean/crops.R` | Flag | `quant_harvest` missing on an observed plot record. | Review overlap with F2 and decide whether one flag can be collapsed. |
| F9 | `impute/crops.R` | Flag | `area_planted_ha` was imputed. | Report imputed count separately from raw missingness. |
| F10 | `impute/crops.R` | Flag | Imputed/composite harvested area exceeds `plotsize`. | Compare with F7 to see whether imputation increases implausible cases. |
| F11 | `clean/crops.R` | Flag | Short-season plot-details rows where `ag3b_01b != 2` or missing. | Keep as audit flag; confirm codebook meaning of `2`. |
| F12 | `clean/crops.R` | Flag | Short-season plot-details rows with blank or missing `plotnum`. | Profile whether joins are affected. |
| F1 | `clean/household_roster.R` | Flag | Duplicate `y4_hhid` in `hh_sec_a`. | Profile duplication rate and confirm first-occurrence retention is acceptable. |
| F2 | `clean/household_roster.R` | Flag | Duplicate `y4_hhid` in `ag_filters`. | Profile duplication rate and confirm first-occurrence retention is acceptable. |
| F3 | `clean/household_roster.R` | Flag | Mixed coding within `lf_filters` module. | Verify against the codebook before publication. |
| F4 | `clean/household_roster.R` | Flag | Duplicate `y4_hhid` in `lf_filters`. | Profile duplication rate and confirm first-occurrence retention is acceptable. |
| F5 | `clean/household_roster.R` | Flag | Participation flags imply structural zero downstream. | Check for any cases where participation is FALSE but quantities are positive. |
| F6 | `clean/household_roster.R` | Flag | Households in `hh_sec_a` with no `ag_filters` match. | Profile missing linkage between roster and agriculture module. |
| F7 | `clean/household_roster.R` | Flag | Households in `hh_sec_a` with no `lf_filters` match. | Profile missing linkage between roster and livestock module. |
| F1  | clean/animal_products.R  | Flag | flag_produced_gate_no — production gate says no.                                     | Review for section mismatch or later imputation. |
| F2  | clean/animal_products.R  | Flag | flag_sold_gate_no — sales gate says no.                                              | Review for section mismatch or later imputation. |
| F3  | clean/animal_products.R  | Flag | flag_true_na_produced — produced quantity is genuinely missing.                      | Review missingness.                              |
| F4  | clean/animal_products.R  | Flag | flag_true_na_unit — production unit is genuinely missing.                            | Review missingness.                              |
| F5  | clean/animal_products.R  | Flag | flag_true_na_sold — sold quantity is genuinely missing.                              | Review missingness.                              |
| F6  | clean/animal_products.R  | Flag | flag_true_na_unitsold — sold unit is genuinely missing.                              | Review missingness.                              |
| F7  | clean/animal_products.R  | Flag | flag_unit_unexpected — production unit is not recognised.                            | Review coding or recode.                         |
| F8  | clean/animal_products.R  | Flag | flag_hides_section_present — hides record exists in product section.                 | Keep as diagnostics.                             |
| F9  | clean/animal_products.R  | Flag | flag_hides_true_na — hides production and sales are both genuinely missing.          | Review missingness.                              |
| F10 | clean/animal_products.R  | Flag | flag_hides_section_misalignment — hides row lacks household linkage.                 | Review alignment.                                |
| F11 | clean/animal_products.R  | Flag | flag_eggs_true_na — egg production and sales are both genuinely missing.             | Review missingness.                              |
| F12 | clean/animal_products.R  | Flag | flag_eggs_section_misalignment — egg row has no poultry support match.               | Review alignment.                                |
| F13 | clean/animal_products.R  | Flag | flag_eggs_feed_alignment_missing — eggs have no matching feed practice.              | Review alignment.                                |
| F14 | clean/animal_products.R  | Flag | flag_egg_feed_category_missing — egg feed category does not match poultry crosswalk. | Review coding or recode.                         |
| F15 | impute/animal_products.R | Flag | flag_produced_imputed_zero — production gate says no and produced was set to zero.   | Imputation rule; keep logged.                    |
| F16 | impute/animal_products.R | Flag | flag_sold_imputed_zero — sales gate says no and sold was set to zero.                | Imputation rule; keep logged.                    |
| F17 | impute/animal_products.R | Flag | flag_produced_annualised — produced quantity was annualised using length.            | Confirm annualisation.                           |
| F18 | impute/animal_products.R | Flag | flag_hides_weight_repair — hides weight needed repair.                               | Review or justify repair.                        |
| F19 | impute/animal_products.R | Flag | flag_hides_type_unmatched — hides records do not match an animal type.               | Review alignment.                                |
| F20 | impute/animal_products.R | Flag | flag_hides_allocation_missing — hides allocation is missing.                         | Review allocation gap.                           |
| F21 | impute/animal_products.R | Flag | flag_rel_prod_imputed — relative hides production was derived.                       | Review derived allocation.                       |
| F22 | impute/animal_products.R | Flag | flag_eggs_feed_missing — egg feed allocation is missing.                             | Review allocation gap.                           |
| F23 | impute/animal_products.R | Flag | flag_eggs_feed_defaulted — egg feed/grazing split was defaulted.                     | Review default assumption.  |
| F1 | clean/milk.R  | Flag | flag_manual_lf06_03_fix — household-specific average milk production override was needed.   | Review and move to impute.    |
| F2 | clean/milk.R  | Flag | flag_processed_lt_psold — processed milk reported lower than product sold.                  | Review for inconsistency.     |
| F3 | clean/milk.R  | Flag | flag_av_missing — average milk production is missing.                                       | Review missingness.           |
| F4 | clean/milk.R  | Flag | flag_non_ruminant_dropped — livestock category dropped because it cannot produce milk here. | Keep as structural exclusion. |
| F5 | impute/milk.R | Flag | flag_disposition_inconsistent — reported milk dispositions are not internally consistent.   | Apply imputation rule.        |
| F6 | impute/milk.R | Flag | flag_milk_conversion_applied — litres converted to kg using density factor.                 | Confirm unit conversion.      |
| F7 | impute/milk.R | Flag | flag_cross_section_feed_mismatch — milk feed record does not match animal support.          | Review alignment.             |

## Review order

1.  Confirm the crop flag set is mutually intelligible and not duplicative where overlaps exist, especially F2/F8 and the harvest-remainder flags.
2.  Decide whether A3 should stay in cleaning as a diagnostic candidate or move closer to the imputation stage.
3.  Confirm that A4 and A5 are the only value-changing crop rules in `impute/crops.R`.
4.  Verify whether F11 is a hard inclusion rule or only an audit flag pending codebook review.
5.  Confirm that duplicate-household flags are truly duplicates and not legitimate multi-row cases.
6.  Verify the livestock coding inconsistency against the codebook.
7.  Check whether roster-to-module non-matches are systematic or random.
8.  Only after those checks should downstream structural-zero logic be hardened.

## Notes

-   The crop workflow is now intentionally stage-segregated: clean for flags and standardisation, impute for value-changing repair.
-   No crop item is excluded at this stage; exclusion should only appear later if a record cannot be imputed or defended.
-   If a flag later becomes impossible to repair, it can be promoted to an exclusion in `05_exclusions_audit.R`, but not before.
-   `grew_crops`, `owned_animals`, and `did_process` remain the ground-truth participation flags for later structural-zero handling.
-   No household is excluded in the clean stage because of these flags.
-   Any later zero-filling should happen in the build or imputation stage, not here.
