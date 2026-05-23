# Flags Review Log — Project 01

Updated to match the revised pipeline structure. In the current convention, cleaning scripts contain flags and harmless standardisations only, while imputation scripts hold value-changing assumptions and repair rules. No item should be treated as an exclusion at this stage; unresolved items should be handled within clean or impute, not excluded here.

## How to use this file

-   Use this log as the single review register before moving through all `impute/` scripts.
-   Keep **flags** for diagnostics, linkage issues, contradictions, and missingness patterns.
-   Keep **assumptions** for explicit value-changing rules, conversions, allocations, and manual repairs.
-   If an item becomes impossible to justify or repair, promote it later to `impute/` or `clean/` rather than treating it as an exclusion here.

## Status labels

-   `documented` — logged and structurally clear.
-   `needs review` — requires a manual decision, profiling, or codebook check.
-   `resolved in review` — ownership is already clear enough at this stage and does not need a separate transition category.
-   `diagnostic only` — keep as an audit flag; no direct action needed now.
-   `resolved` — already handled and no longer an active review item.

## Review table

| Variable | Stage | Script | Type | Description | Downstream action | Status | Notes |
|---------|---------|---------|---------|---------|---------|---------|---------|
| gps_area_zero_rule | clean | `clean/crops.R` | assumption | GPS readings of `0` are treated as unusable and therefore missing for diagnostics. | Confirm this remains standardisation only, not imputation. | documented | Linked to `flag_gps_area_zero`. |
| plotsize_candidate_rule | clean | `clean/crops.R` | assumption | GPS area is preferred over farmer-reported area for `plotsize_candidate` where available. | Confirm against LSMS-ISA area-measurement guidance. | needs review | Keep rationale short in README/methods note. |
| area_harvested_alt_candidate_rule | clean | `clean/crops.R` | assumption | `area_harvested_alt` is retained as a candidate proportional harvested-area estimate. | Decide whether it stays diagnostic only or becomes an imputation input. | needs review | This is a candidate, not a final replacement. |
| area_planted_ha_impute_rule | impute | `impute/crops.R` | assumption | Missing `area_planted_ha` may be replaced using `area_harvested_ha`. | Profile affected records and report imputed count separately. | needs review | Value-changing rule; belongs in impute. |
| total_harvest_rule | impute | `impute/crops.R` | assumption | `total_harvest = harvest_remain + quant_harvest`. | Keep as explicit rule and retain sensitivity option if needed. | documented | User preference: `harvest_remain`, not `quant_unharvested`. [cite:540] |
| gateway_no_structural_zero_rule | impute | `impute/animal_products.R` | assumption | Gateway “no” responses imply structural zeros in imputation. | Keep explicit in impute and report counts. | documented | Separate from clean-stage diagnostics. |
| hides_slaughter_link_rule | impute | `impute/animal_products.R` | assumption | Hides allocation is based on slaughter-linked support, not animals that died from other causes. | Review and document justification. | needs review | Domain rule; not a cleaning step. |
| eggs_feed_crosswalk_rule | impute | `impute/animal_products.R` | assumption | Egg feed allocation uses the poultry feed crosswalk. | Keep explicit in impute. | documented | Cross-section dependency with poultry support. |
| feed_split_default_rule | impute | `impute/animal_products.R` | assumption | Missing feed splits may be defaulted only in imputation. | Keep explicit and report any defaults. | needs review | Reviewable default, not silent repair. |
| av_milk_from_disposition_rule | impute | `impute/milk.R` | assumption | Missing average milk production may be filled using reported disposition values. | Document method explicitly and count affected records. | needs review | Move ownership out of clean. |
| processed_psold_repair_rule | impute | `impute/milk.R` | assumption | If `processed < psold`, processed milk is replaced using `psold`. | Keep as a logged repair rule. | documented | Should not remain an implicit clean-stage fix. |
| milk_uncertainty_range4_rule | impute | `impute/milk.R` | assumption | Milk uncertainty is approximated using `range / 4`. | Document and justify in methods note. | needs review | Sensitivity candidate if needed later. |
| ruminant_feed_factor_rule | impute | `impute/milk.R` | assumption | Feed requirement factors are applied uniformly within ruminant groups. | Keep explicit. | documented | Cross-section dependency with animal feed data. |
| milk_density_rule | impute | `impute/milk.R` | assumption | Milk density is `1.03 kg/litre`. | Confirm against source standard. | needs review | Unit conversion assumption. |
| maize_manual_repair_rule | impute | `impute/destinations.R` | assumption | Household-specific maize repair for `y4_hhid == 8659-001` is treated as an imputation decision, not a clean-stage fix. | Decide whether to keep as manual repair or replace with defensible imputation. | needs review | Currently flagged in clean as `flag_manual_hh_fix_needed`. |
| product_density_conversion_rule | impute | `impute/ag_produce.R` | assumption | Litre-to-kg conversion uses product-specific density factors. | Keep conversion table explicit and profile rows with missing factors. | documented | AP1 in script. |
| manual_input_split_rule | impute | `impute/ag_produce.R` | assumption | Household-specific input split for `y4_hhid == "3208-001"`. | Re-check raw record and retain as explicit manual split if still needed. | needs review | AP2 in script; household-level manual rule. |
| input_fallback_full_rule | impute | `impute/ag_produce.R` | assumption | Final fallback assigns full input when allocation remains unresolved. | Profile affected rows and report residual uncertainty. | needs review | AP3 in script; fallback should stay reviewable. |
| flag_dup_roster | clean | `clean/household_roster.R` | flag | Duplicate `y4_hhid` in `hh_sec_a`. | Profile duplication rate and confirm first-occurrence retention is acceptable. | needs review | Currently message-only; add to review log even if not stored as column. |
| flag_dup_ag_filters | clean | `clean/household_roster.R` | flag | Duplicate `y4_hhid` in `ag_filters`. | Profile duplication rate and confirm first-occurrence retention is acceptable. | needs review | Message-only flag. |
| flag_mixed_lf_coding | clean | `clean/household_roster.R` | flag | Mixed coding within `lf_filters` (`yes/no` vs numeric `1/2`). | Verify against codebook before publication. | needs review | Survey coding issue, not imputation. |
| flag_dup_lf_filters | clean | `clean/household_roster.R` | flag | Duplicate `y4_hhid` in `lf_filters`. | Profile duplication rate and confirm first-occurrence retention is acceptable. | needs review | Message-only flag. |
| flag_structural_zero_participation_check | clean | `clean/household_roster.R` | flag | Participation flags imply structural zeros downstream. | Check whether any households have `FALSE` participation but positive quantities later. | documented | Ground-truth participation flags remain `grew_crops`, `owned_animals`, `did_process`. [<file:569>] |
| flag_no_match_ag | clean | `clean/household_roster.R` | flag | Households in `hh_sec_a` with no `ag_filters` match. | Profile missing linkage to agriculture module. | needs review | `flag_no_match_ag` is message-only in current script. |
| flag_no_match_lf | clean | `clean/household_roster.R` | flag | Households in `hh_sec_a` with no `lf_filters` match. | Profile missing linkage to livestock module. | needs review | `flag_no_match_lf` is message-only in current script. |
| flag_gps_area_zero | clean | `clean/crops.R` | flag | `gps_area == 0`, treated as unusable for diagnostics. | Keep as audit flag and confirm no downstream misuse. | diagnostic only | `flag_gps_area_zero`. |
| flag_harvest_contradiction | clean | `clean/crops.R` | flag | `harvested == "no"` but `quant_harvest` is recorded. | Profile by crop and season; decide whether later repair is defensible. | needs review | `flag_harvest_contradiction`. |
| flag_harvest_quantity_missing | clean | `clean/crops.R` | flag | `harvested == "yes"` but `quant_harvest` is missing. | Review for enumerator error versus later imputation. | needs review | `flag_harvest_quantity_missing`. |
| flag_harvest_missing | clean | `clean/crops.R` | flag | `harvested` response is missing on an observed crop record. | Profile missingness before any repair. | needs review | `flag_harvest_missing`. |
| flag_harvest_remain_missing | clean | `clean/crops.R` | flag | `harvest_remain` missing when finished-harvest logic implies it should be observed. | Check overlap with harvest quantity missingness. | needs review | `flag_harvest_remain_missing`. |
| flag_area_planted_missing | clean | `clean/crops.R` | flag | `area_planted` missing on an observed plot record. | Hand off to imputation if a defensible fallback exists. | needs review | `flag_area_planted_missing`. |
| flag_plotnum_missing | clean | `clean/crops.R` | flag | `plotnum` missing on crop record. | Check join loss and downstream matching impact. | needs review | `flag_plotnum_missing`. |
| flag_area_harvested_gt_plotsize | clean | `clean/crops.R` | flag | Harvested area candidate exceeds `plotsize_candidate`. | Review for measurement mismatch or implausible record. | needs review | `flag_area_harvested_gt_plotsize`. |
| flag_quant_harvest_missing | clean | `clean/crops.R` | flag | `quant_harvest` is missing on observed plot record. | Review overlap with `F-CROP-03` and decide whether one flag can be collapsed. | needs review | `flag_quant_harvest_missing`. |
| flag_area_planted_ha_imputed | impute | `impute/crops.R` | flag | `area_planted_ha` was imputed. | Report imputed count separately from raw missingness. | documented | Imputation-stage flag. |
| flag_area_harvested_imputed_gt_plotsize | impute | `impute/crops.R` | flag | Imputed/composite harvested area still exceeds `plotsize`. | Compare with clean-stage mismatch count. | needs review | Post-imputation plausibility check. |
| flag_short_code | clean | `clean/crops.R` | flag | Short-season plot-details rows where `ag3b_01b != 2` or missing. | Confirm codebook meaning of `2`; keep as audit flag until then. | needs review | `flag_short_code`. |
| flag_blank_plotnum | clean | `clean/crops.R` | flag | Short-season plot-details rows with blank or missing `plotnum`. | Profile whether joins are affected. | needs review | `flag_blank_plotnum`. |
| flag_produced_gate | clean | `clean/animal_products.R` | flag | Production gate says yes. | Review for section mismatch or later imputation. | Diagnostic only. | . |
| flag_sold_gate | clean | `clean/animal_products.R` | flag | Sales gate says yes. | Review for section mismatch or later imputation. | Diagnostic only. |  |
| flag_true_na_produced | clean | `clean/animal_products.R` | flag | Produced quantity is genuinely missing. | Review missingness. | documented |  |
| flag_true_na_unit | clean | `clean/animal_products.R` | flag | Production unit is genuinely missing. | Review missingness. | documented |  |
| flag_egg_overuse | clean | `clean/animal_products.R` | flag | Eggs sales exceed production. | Review for section mismatch or later imputation. | documented |  |
| flag_egg_unaccounted | clean | `clean/animal_products.R` | flag |  | Review for section mismatch or later imputation. | documented. | For consumption imputation |
| flag_true_na_sold | clean | `clean/animal_products.R` | flag | Sold quantity is genuinely missing. | Review missingness. | documented |  |
| flag_true_na_unitsold | clean | `clean/animal_products.R` | flag | Sold unit is genuinely missing. | Review missingness. | documented |  |
| flag_unit_unexpected | clean | `clean/animal_products.R` | flag | Production unit is not recognised. | Review coding or recode. | documented |  |
| flag_hides_section_present | clean | `clean/animal_products.R` | flag | Hides record exists in product section. | Keep as diagnostics. | diagnostic only |  |
| flag_hides_true_na | clean | `clean/animal_products.R` | flag | Hides production and sales are both genuinely missing. | Review missingness. | diagnostic only |  |
| flag_eggs_gate | clean | clean/animal_products.R | flag | Egg production yes | Keep as diagnostics. | diagnostic only |  |
| flag_eggs_section_misalignment | clean | `clean/animal_products.R` | flag | Egg row has no poultry support match. | Review alignment. | documented |  |
| flag_eggs_feed_alignment_missing | clean | `clean/animal_products.R` | flag | Eggs have no matching feed practice. | Review alignment. | documented |  |
| flag_egg_feed_category_missing | clean | `clean/animal_products.R` | flag | Egg feed category does not match poultry crosswalk. | Review coding or recode. | documented |  |
| flag_chicken_no_egg | clean | clean/animal_products.R | flag | Poultry has no egg support match. | Review for plausibility. | documented |  |
| flag_produced_imputed_zero | impute | `impute/animal_products.R` | flag | Production gate says no and produced was set to zero. | Imputation rule; keep logged. | documented | Existing item from prior review file. |
| flag_sold_imputed_zero | impute | `impute/animal_products.R` | flag | Sales gate says no and sold was set to zero. | Imputation rule; keep logged. | documented | Existing item from prior review file. |
| flag_produced_annualised | impute | `impute/animal_products.R` | flag | Produced quantity was annualised using length. | Confirm annualisation. | needs review | Existing item from prior review file. |
| flag_hides_weight_repair | impute | `impute/animal_products.R` | flag | Hides weight needed repair. | Review or justify repair. | needs review | Existing item from prior review file. |
| flag_hides_type_unmatched | impute | `impute/animal_products.R` | flag | Hides records do not match an animal type. | Review alignment. | needs review | Existing item from prior review file. |
|  |  |  |  |  |  |  |  |
| flag_hides_allocation_missing | impute | `impute/animal_products.R` | flag | Hides allocation is missing. | Review allocation gap. | needs review | Existing item from prior review file. |
| flag_rel_prod_imputed | impute | `impute/animal_products.R` | flag | Relative hides production was derived. | Review derived allocation. | needs review | Existing item from prior review file. |
| flag_eggs_feed_missing | impute | `impute/animal_products.R` | flag | Egg feed allocation is missing. | Review allocation gap. | needs review | Existing item from prior review file. |
| flag_eggs_feed_defaulted | impute | `impute/animal_products.R` | flag | Egg feed/grazing split was defaulted. | Review default assumption. | needs review | Existing item from prior review file. |
| flag_manual_lf06_03_fix | clean | `clean/milk.R` | flag | Household-specific average milk production override was needed. | Review and move to impute. | needs review | Existing item from prior review file. |
| flag_processed_lt_psold | clean | `clean/milk.R` | flag | Processed milk reported lower than product sold. | Review for inconsistency. | needs review | Existing item from prior review file. |
| flag_av_missing | clean | `clean/milk.R` | flag | Average milk production is missing. | Review missingness. | needs review | Existing item from prior review file. |
| flag_non_ruminant_dropped | clean | `clean/milk.R` | flag | Non-ruminant category dropped because it cannot produce milk here. | Keep as structural exclusion. | resolved | Existing item from prior review file. |
| flag_disposition_inconsistent | impute | `impute/milk.R` | flag | Reported milk dispositions are not internally consistent. | Apply imputation rule. | needs review | Existing item from prior review file. |
| flag_milk_conversion_applied | impute | `impute/milk.R` | flag | Litres converted to kg using density factor. | Confirm unit conversion. | documented | Existing item from prior review file. |
| flag_cross_section_feed_mismatch | impute | `impute/milk.R` | flag | Milk feed record does not match animal support. | Review alignment. | needs review | Existing item from prior review file. |
| flag_conv_review | clean | clean/recall.R | flag | Conversion not possible | Cross reference units and impute | documented | Overlap with missing units |
| flag_dup_recall_keys | clean | clean/recall.R | flag | Duplicate (y4_hhid, itemcode) combinations in raw recall data. | Profile duplicates and confirm first-occurrence handling is justified. | documented | Counts duplicate keys in raw input. |
| flag_quantity_missing | clean | clean/recall.R | flag | Consumed items with missing quantity. | Profile missingness and decide whether to keep as diagnostic only. | documented | Row-level flag on recall_kg. |
| flag_value_missing | clean | clean/recall.R | flag | Consumed items with purchase amount but missing value. | Review whether value is genuinely missing or structurally absent. | documented | Row-level flag on recall_kg. |
| flag_source_missing | clean | clean/recall.R | flag | Purchased items with value present but source missing. | Review as a consistency check, not an imputation rule. | documented | Row-level flag on recall_kg. |
| flag_consumed_no_but_quantity | clean | clean/recall.R | flag | Items marked not consumed but with positive quantity. | Profile as contradiction and confirm coding logic. | documented | This should be in the summary if recall_kg is the object used. |
| flag_unit_missing | clean | clean/recall.R | flag | Consumed items with quantity but missing unit. | Review missing unit patterns before deciding on repair. | documented |  |
| flag_unit_production_missing | clean | clean/recall.R | flag | Consumed-from-production items with missing production unit. | Review missing unit patterns before deciding on repair. | documented |  |
| flag_unit_purchases_missing | clean | clean/recall.R | flag | Consumed-from-purchases items with missing purchase unit. | Review missing unit patterns before deciding on repair. | documented |  |
| flag_unit_gifts_missing | clean | clean/recall.R | flag | Consumed-from-gifts items with missing gift unit. | Review missing unit patterns before deciding on repair. | documented |  |
| flag_quantity_component_mismatch | clean | clean/recall.R | flag | Converted quantity does not reconcile with purchases,production, and gifts. | Investigate as a reconciliation check. | documented | Uses quantity_kg \< acquired_kg |
| flag_dup_animals | clean | clean/animals.R | flag | Duplicate (y4_hhid, lvstckid) combinations in lf_sec_02. | Profile duplicate rate and confirm handling is acceptable. | documented | Row-level diagnostic flag on animals. |
| flag_bought_zero_from_gate | clean | clean/animals.R | flag | ownershp == "yes" & lf02_06 == "no" implies zero bought animals later. | Keep as structural-zero diagnostic; repair belongs in impute. | documented | Row-level flag on animals. |
| flag_gift_zero_from_gate | clean | clean/animals.R | flag | ownershp == "yes" & lf02_09 == "no" implies zero gift animals later. | Keep as structural-zero diagnostic; repair belongs in impute. | documented | Row-level flag on animals. |
| flag_gifted_zero_from_gate | clean | clean/animals.R | flag | ownershp == "yes" & lf02_12 == "no" implies zero gifted animals later. | Keep as structural-zero diagnostic; repair belongs in impute. | documented | Row-level flag on animals. |
| flag_disease_zero_from_gate | clean | clean/animals.R | flag | ownershp == "yes" & lf02_15 == "no" implies zero disease losses later. | Keep as structural-zero diagnostic; repair belongs in impute. | documented | Row-level flag on animals. |
| flag_theft_zero_from_gate | clean | clean/animals.R | flag | ownershp == "yes" & lf02_18 == "no" implies zero theft losses later. | Keep as structural-zero diagnostic; repair belongs in impute. | documented | Row-level flag on animals. |
| flag_injury_zero_from_gate | clean | clean/animals.R | flag | ownershp == "yes" & lf02_21 == "no" implies zero injury losses later. | Keep as structural-zero diagnostic; repair belongs in impute. | documented | Row-level flag on animals. |
| flag_sold_zero_from_gate | clean | clean/animals.R | flag | ownershp == "yes" & lf02_24 == "no" implies zero sold animals later. | Keep as structural-zero diagnostic; repair belongs in impute. | documented | Row-level flag on animals. |
| flag_slaughter_zero_from_gate | clean | clean/animals.R | flag | ownershp == "yes" & lf02_29 == "no" implies zero slaughter later. | Keep as structural-zero diagnostic; repair belongs in impute. | documented | Row-level flag on animals. |
| flag_current_missing | clean | clean/animals.R | flag | Both ind and exotic are missing when ownership is yes. | Profile missingness and confirm whether imputation is needed. | documented | Row-level flag on animals. |
| flag_ownership | clean | clean/animals.R | flag | Household reports ownership. | Use as gate flag only; should match roster | documented | Row-level flag on animals. |
| flag_in_out_misaligned | clean | clean.animals.R | flag | all_lost exceeds max_owned | Investigate as plausibility check | documented | Row-level flag on animals_sub. |
| flag_slaughter_gt_max_owned | clean | clean/animals.R | flag | Slaughter exceeds maximum observed ownership. | Investigate as plausibility check. | documented | Row-level flag on animals_sub. |
| flag_ssold_gt_slaughter | clean | clean/animals.R | flag | Slaughtered-sold count exceeds slaughtered total. | Investigate as plausibility check. | documented | Row-level flag on animals_sub. |
| flag_current_missing_sub | clean | clean/animals.R | flag | Current stock measure is missing in the derived stock table. | Review missingness before publication. | documented | Row-level flag on animals_sub. |
| flag_current_own_mismatch | clean | clean/animals.R | flag | Current stock is less than ind + exotic after missing values are handled. | Investigate as ownership consistency check. | documented | Row-level flag on animals_sub. |
| flag_weight_missing | clean | clean/animals.R | flag | Slaughter weight is missing where slaughter occurs. | Review as reference-data or entry-gap issue. | documented | Row-level flag on wa. |
| flag_breakdown_type_missing | clean | clean/animals.R | flag | Livestock type did not match carcass breakdown reference. | Check reference crosswalk and unmatched types. | documented | Row-level flag on wa. |
| flag_expected_feed_section | clean | clean/animals.R | flag | Household-animal record expected to have a feed section match. | Join helper for feed review; keep only if needed downstream. | diagnostic only | Join helper, not necessarily a final review item. |
| flag_feed_only | clean | clean/animals.R | flag | Feed record exists without matching owned-animal record. | Review unmatched feed households. | documented | Row-level flag on feed. |
| flag_animal_only | clean | clean/animals.R | flag | Owned-animal record exists without feed data. All related to 'other animal' | Review whether missing feed is acceptable or needs follow-up. | documented | Row-level flag on feed. |
| flag_both_sections | clean | clean/animals.R | flag | Both animal and feed sections matched. | Diagnostic only; useful for QA counts. | diagnostic only | Not really a problem flag. |
| flag_feed1_unexpected | clean | clean/animals.R | flag | Primary feed practice is outside the expected category set. | Verify against codebook before publication. | documented | Row-level flag on feed. |
| flag_feed2_unexpected | clean | clean/animals.R | flag | Secondary feed practice is outside the expected category set. | Verify against codebook before publication. | documented | Row-level flag on feed. |
| flag_tot_quantity_missing | clean | clean/animals.R | flag | Total fish quantity is missing for a reported species. | Review missingness in fishery totals. | documented | Row-level flag on fishes. |
| flag_tot_unit_missing | clean | clean/animals.R | flag | Total fish unit is missing for a reported species. | Review missingness in fishery units. | documented | Row-level flag on fishes. |

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

## Per-script TODOs

### `clean/animals.R`

-   [x] Resolve the inline comment "include donkeys?" in the `flag_milk_animal` derivation — confirm against domain knowledge before the flag feeds into milk analysis. → not included
-   [x] Confirm `flag_current_missing` and `flag_current_components_missing` are genuinely distinct populations, not the same rows counted twice. → deleted flag_current_components_missing
-   [x] Confirm `flag_animal_only` and `flag_true_na_feed1` are not identical; if they are, collapse to one flag and remove the duplicate. → duplicated removed `flag_true_na_feed1`
-   [ ] Review the eight `*_zero_from_gate` flags as a batch: confirm zero-fill for all of them belongs in `impute/animals.R`, not here.
-   [x] Profile `flag_slaughter_gt_max_owned` and `flag_ssold_gt_slaughter` for implausible records before deciding whether any become exclusion candidates later. → possible imputation
-   [x] Check carcass breakdown crosswalk coverage (`flag_breakdown_type_missing`): identify which livestock types are unmatched and whether the reference table needs expanding. → no
-   [x] Feed duplicate saving and flag-summary blocks for `feed_short` are repeated twice in the script — remove the duplicate block before portfolio publication (unhealthy pattern: copy-pasted code block that should appear once).

### `clean/animal_products.R`

-   [x] All flags in this script were already present in the review table from the prior session. Confirm that `produce.rds`, `hides.rds`, and `mass_eggs.rds` remain the canonical clean outputs and that no repair logic has silently been added here since the last review.
-   [x] Check `excl_eggs.csv`: the field name is `excl` and the only value is `"Needs feed match"`. This looks like an exclusion marker, which contradicts the no-exclusion-at-clean-stage rule. Either rename to a flag or confirm this CSV is only used as a diagnostic list by the impute script, not as a hard exclusion filter. → deleted all exclude code
-   [x] Confirm that `flag_hides_section_present` (always `1L` for hides rows) is intentional as a class identifier rather than a diagnostic flag — if so, label it clearly in the script.

### `clean/milk.R`

-   [ ] Confirm `milk_support` join logic: `flag_milk_support_missing` and `flag_section_mismatch_milked_gt_owned` should be reviewed together because both come from the same cross-reference step.
-   [ ] Check whether `milk <- milk[is.na(milkable) | milkable == 1]` is truly a clean-stage filter or an exclusion; if it removes rows, that needs to be justified in the clean-stage notes.
-   [ ] Resolve `flag_manual_av_fix_needed` row list (`1001-001`, `1002-001`, `2943-001`) and decide whether those are manual clean-stage fixes or should move into `impute/milk.R` as explicit repair cases.
-   [ ] Profile overlap among `flag_av_missing`, `flag_disposition_present_but_av_missing`, and `flag_zero_milked_with_output`; they likely describe the same family of inconsistencies from different angles.
-   [ ] Check whether `flag_fix_processing_input` is merely a diagnostic on `processed_raw < psold_raw` or a value-changing repair rule disguised as a clean-stage flag.
-   [ ] Confirm `flag_daily_output_implausible` threshold (`av_raw > 6` with `milked == 1`) against domain expectations; if this is just an exploratory heuristic, label it as such.
-   [ ] Decide whether `flag_disposition_exceeds_production` is a hard contradiction or a diagnostic that should be retained until imputation logic is finalized.
-   [ ] Confirm the script no longer contains imputation-only concepts in comments: uncertainty, feed requirement, unit conversion, and fallback should stay out of clean-stage language.

### Cross-script overlaps to check

-   `flag_current_missing` and `flag_current_components_missing` (`clean/animals.R`) — profile to confirm they are distinct.
-   `flag_animal_only` and `flag_true_na_feed1` (`clean/animals.R`) — profile to confirm they are not identical.
-   `flag_quantity_missing` and `flag_consumed_no_but_quantity` (`clean/recall.R`) — review together as mirror-image gate/quantity mismatches.
-   The eight gateway-zero flags in `clean/animals.R` follow the same logic as `gateway_no_structural_zero_rule` in `impute/animal_products.R`; confirm the imputation-stage equivalent exists or will be added in `impute/animals.R`.

### `clean/milk.R`

-   [ ] Confirm `milk_support` join logic: `flag_milk_support_missing` and `flag_section_mismatch_milked_gt_owned` should be reviewed together because both come from the same cross-reference step.
-   [ ] Check whether `milk <- milk[is.na(milkable) | milkable == 1]` is truly a clean-stage filter or an exclusion; if it removes rows, that needs to be justified in the clean-stage notes.
-   [ ] Resolve `flag_manual_av_fix_needed` row list (`1001-001`, `1002-001`, `2943-001`) and decide whether those are manual clean-stage fixes or should move into `impute/milk.R` as explicit repair cases.
-   [ ] Profile overlap among `flag_av_missing`, `flag_disposition_present_but_av_missing`, and `flag_zero_milked_with_output`; they likely describe the same family of inconsistencies from different angles.
-   [ ] Check whether `flag_fix_processing_input` is merely a diagnostic on `processed_raw < psold_raw` or a value-changing repair rule disguised as a clean-stage flag.
-   [ ] Confirm `flag_daily_output_implausible` threshold (`av_raw > 6` with `milked == 1`) against domain expectations; if this is just an exploratory heuristic, label it as such.
-   [ ] Decide whether `flag_disposition_exceeds_production` is a hard contradiction or a diagnostic that should be retained until imputation logic is finalized.
-   [ ] Confirm the script no longer contains imputation-only concepts in comments: uncertainty, feed requirement, unit conversion, and fallback should stay out of clean-stage language.

### Cross-script overlaps to check

-   `flag_av_missing` (`clean/milk.R`) overlaps conceptually with `flag_disposition_present_but_av_missing`; profile both together before any manual repair.
-   `flag_fix_processing_input` (`clean/milk.R`) is the clean-stage analogue of the imputation rule `processed < psold` in `impute/milk.R`; confirm there is no silent move to impute still hiding in the clean script.
-   `flag_section_mismatch_milked_gt_owned` (`clean/milk.R`) should be checked alongside `flag_milk_support_missing`; both originate from the same support crosswalk and may collapse into one review note.
