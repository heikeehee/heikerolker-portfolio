# =============================================================================
# impute/destinations.R
# PURPOSE: Apply repair, gateway zeros, harvest/disposition merges,
# exclusion review, and residue estimation for crop and tree flows
# INPUT: clean/crop_disp.rds, clean/tree_disp.rds,
# imputed/pc.rds, imputed/pt.rds,
# raw$ref$rpr, raw$ref$cropmap
# OUTPUT: data/processed/01/impute/mass_crops.rds
#         data/processed/01/impute/mass_trees.rds
#         data/processed/01/impute/mass_allcrops.rds
#         data/processed/01/impute/mass_residue.rds
#         data/processed/01/impute/mass_residue.csv
#         data/processed/01/impute/*_flag_summary.csv
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "01", "03_impute"), showWarnings = FALSE, recursive = TRUE)

crop_disp <- readRDS(here::here("data", "processed", "01", "clean", "crop_disp.rds"))
tree_disp <- readRDS(here::here("data", "processed", "01", "clean", "tree_disp.rds"))
pc <- readRDS(here::here("data", "processed", "01", "impute", "pc_imputed.rds"))
pt <- readRDS(here::here("data", "processed", "01", "impute", "pt_imputed.rds"))

flag_summary <- function(dt) {
  fc <- names(dt)[grepl("^flag_", names(dt))]
  data.table(
    Variable = fc,
    Script = "impute/destinations.R",
    Type = "flag",
    Description = fc,
    Tier = "diagnostic",
    Method = "count rows with flag == 1",
    Status = "implemented",
    Notes = "",
    n = vapply(fc, function(col) dt[get(col) == 1L, .N], integer(1))
  )[order(-n)]
}

# =============================================================================
# TIER 1: GATEWAY ZERO LOGIC
# =============================================================================

# Crop disposition zeroing
pn_crops <- pc[, .(nplots = uniqueN(plotnum)), by = .(y4_hhid, cropid)]

chh <- pc[, .(
  harvest = sum(quant_harvest, na.rm = TRUE),
  harvest_remain = sum(harvest_remain, na.rm = TRUE),
  area_planted = sum(area_planted_ha, na.rm = TRUE),
  total_harvest = sum(total_harvest, na.rm = TRUE)
), by = .(y4_hhid, type, cropid)]

chh[, yield := fifelse(!is.na(area_planted) & area_planted > 0, total_harvest / area_planted, NA_real_)]

cd <- copy(crop_disp)
cd <- cd[, .(y4_hhid, type, cropid,
             sold_raw, stored_raw, losses_pct_raw, consumed_raw,
             seed_raw, payment_raw, gifts_raw, feed_raw, residue_raw)]
cd <- cd[, lapply(.SD, sm), .SDcols = is.numeric, by = .(y4_hhid, type, cropid)]

crops_merged <- merge(chh, cd, by = c("y4_hhid", "type", "cropid"), all = TRUE)
crops_merged <- merge(crops_merged, pn_crops, by = c("y4_hhid", "cropid"), all.x = TRUE)

crops_merged[, flag_crop_no_production_match := fifelse(is.na(harvest), 1L, 0L)]
crops_merged[, flag_crop_no_disposition_match := fifelse(is.na(sold_raw) & is.na(consumed_raw), 1L, 0L)]
crops_merged[, flag_crop_yield_missing := fifelse(is.na(yield), 1L, 0L)]
crops_merged[, flag_crop_area_missing := fifelse(is.na(area_planted), 1L, 0L)]

message("flag_crop_no_production_match: ", crops_merged[flag_crop_no_production_match == 1L, .N])
message("flag_crop_no_disposition_match: ", crops_merged[flag_crop_no_disposition_match == 1L, .N])
message("flag_crop_yield_missing: ", crops_merged[flag_crop_yield_missing == 1L, .N])
message("flag_crop_area_missing: ", crops_merged[flag_crop_area_missing == 1L, .N])

crops_merged[, sold := fifelse(sale == "no", 0, as.numeric(sold_raw))]
crops_merged[, stored := fifelse(storage == "no", 0, as.numeric(stored_raw))]
crops_merged[, losses := fifelse(lost == "no", 0, as.numeric(losses_pct_raw) / 10)]
crops_merged[, consumed := as.numeric(consumed_raw)]
crops_merged[, seed := as.numeric(seed_raw)]
crops_merged[, payment := as.numeric(payment_raw)]
crops_merged[, gifts := as.numeric(gifts_raw)]
crops_merged[, feed := as.numeric(feed_raw)]
crops_merged[, residue := as.numeric(residue_raw)]

crops_merged[, smd := sold + stored + losses + consumed + payment + gifts + feed]
crops_merged[, diff := harvest - smd]
crops_merged[, diffp := fifelse(!is.na(harvest) & harvest != 0, diff * 100 / harvest, NA_real_)]

crops_merged[, flag_sold_imputed_zero := fifelse(sale == "no", 1L, 0L)]
crops_merged[, flag_stored_imputed_zero := fifelse(storage == "no", 1L, 0L)]
crops_merged[, flag_losses_imputed_zero := fifelse(lost == "no", 1L, 0L)]
crops_merged[, flag_crop_disposition_inconsistent := fifelse(
  !is.na(harvest) & !is.na(smd) & (smd > harvest * 1.3 | smd < harvest * 0.7),
  1L, 0L
)]

saveRDS(crops_merged, here::here("data", "processed", "01", "impute", "mass_crops.rds"), compress = TRUE)
readr::write_csv(as.data.frame(flag_summary(crops_merged)),
                 here::here("data", "processed", "01", "impute", "mass_crops_flag_summary.csv"))

# Tree disposition
pn_trees <- pt[, .(nplots = uniqueN(plotnum)), by = .(y4_hhid, cropid)]

thh <- pt[, .(
  harvest = sum(harvest, na.rm = TRUE),
  ntrees = sum(ntrees, na.rm = TRUE)
), by = .(y4_hhid, type, cropid)]

thh[, yield := fifelse(!is.na(ntrees) & ntrees > 0, harvest / ntrees, NA_real_)]

td <- copy(tree_disp)
td <- td[, .(y4_hhid, type, cropid,
             sold_raw, stored_raw, losses_pct_raw, consumed_raw,
             seed_raw, payment_raw, gifts_raw, feed_raw)]
td <- td[, lapply(.SD, sm), .SDcols = is.numeric, by = .(y4_hhid, type, cropid)]

trees_merged <- merge(thh, td, by = c("y4_hhid", "type", "cropid"), all = TRUE)
trees_merged <- merge(trees_merged, pn_trees, by = c("y4_hhid", "cropid"), all.x = TRUE)

trees_merged[, flag_tree_no_production_match := fifelse(is.na(harvest), 1L, 0L)]
trees_merged[, flag_tree_no_disposition_match := fifelse(is.na(sold_raw) & is.na(consumed_raw), 1L, 0L)]
trees_merged[, flag_tree_yield_missing := fifelse(is.na(yield), 1L, 0L)]
trees_merged[, flag_tree_ntrees_zero := fifelse(!is.na(ntrees) & ntrees == 0, 1L, 0L)]

message("flag_tree_no_production_match: ", trees_merged[flag_tree_no_production_match == 1L, .N])
message("flag_tree_no_disposition_match: ", trees_merged[flag_tree_no_disposition_match == 1L, .N])
message("flag_tree_yield_missing: ", trees_merged[flag_tree_yield_missing == 1L, .N])

trees_merged[, sold := fifelse(sale == "no", 0, as.numeric(sold_raw))]
trees_merged[, stored := fifelse(storage == "no", 0, as.numeric(stored_raw))]
trees_merged[, losses := fifelse(lost == "no", 0, as.numeric(losses_pct_raw) / 10)]
trees_merged[, consumed := as.numeric(consumed_raw)]
trees_merged[, seed := as.numeric(seed_raw)]
trees_merged[, payment := as.numeric(payment_raw)]
trees_merged[, gifts := as.numeric(gifts_raw)]
trees_merged[, feed := as.numeric(feed_raw)]

trees_merged[, smd := sold + stored + losses + consumed + payment + gifts + feed]
trees_merged[, diff := harvest - smd]
trees_merged[, diffp := fifelse(!is.na(harvest) & harvest != 0, diff * 100 / harvest, NA_real_)]

trees_merged[, flag_tree_disposition_inconsistent := fifelse(
  !is.na(harvest) & !is.na(smd) & (smd > harvest * 1.3 | smd < harvest * 0.7),
  1L, 0L
)]

saveRDS(trees_merged, here::here("data", "processed", "01", "impute", "mass_trees.rds"), compress = TRUE)
readr::write_csv(as.data.frame(flag_summary(trees_merged)),
                 here::here("data", "processed", "01", "impute", "mass_trees_flag_summary.csv"))

# Combined crops + trees
ct <- crops_merged[, .(y4_hhid, type, cropid, harvest, sold, stored, seed,
                       losses, consumed, payment, gifts, feed, residue, smd)]
tc <- trees_merged[, .(y4_hhid, type, cropid, harvest, sold, stored, seed,
                       losses, consumed, payment, gifts, feed, smd)]
tc[, residue := NA_real_]

allcrops <- rbindlist(list(ct, tc), fill = TRUE)
saveRDS(allcrops, here::here("data", "processed", "01", "impute", "mass_allcrops.rds"), compress = TRUE)

# Crop residue estimation
residue_disp <- crop_disp[, .(y4_hhid, cropid, residue_use, residue_raw, value_residue)]
residue_disp <- residue_disp[residue_use != "crop produces no residue"]
residue_disp[, flag_no_residue_category_dropped := 1L]

rpr_ref <- raw$ref$rpr[AreaName == "Tanzania, United Rep. of"]
cropmap <- raw$ref$cropmap

res_hh <- pc[, .(
  harvest = sum(quant_harvest, na.rm = TRUE),
  harvest_remain = sum(harvest_remain, na.rm = TRUE),
  total_harvest = sum(total_harvest, na.rm = TRUE)
), by = .(y4_hhid, cropid, type)]

res_hh <- cropmap[res_hh, on = .(cropid)]
res_hh <- residue_disp[res_hh, on = .(y4_hhid, cropid)]

res_full <- rpr_ref[res_hh, on = .(Item)]

res_full[, residue_sold_DM := as.numeric(residue_raw) / Dry_matter]
res_full[, flag_rpr_match_missing := fifelse(is.na(RPR) | is.na(Dry_matter), 1L, 0L)]

res_full[, Residues_DM := total_harvest * Dry_matter * RPR * UsedRes]
res_full[, Residues_wet := total_harvest * RPR * UsedRes]
res_full[, Residues_DM_alt := (total_harvest + harvest_remain) * Dry_matter * RPR * UsedRes]
res_full[, flag_residue_derived := fifelse(!is.na(Residues_DM), 1L, 0L)]

res_full[, grazing_res := fifelse(
  residue_use %in% c("for grazing own animals", "feeding own animals", "residue was left in field"),
  Residues_DM, 0
)]
res_full[, flag_grazing_residue_allocated := fifelse(grazing_res > 0, 1L, 0L)]

res_out <- res_full[, .(y4_hhid, cropid, type, harvest, harvest_remain, total_harvest, Dry_matter,
                        residue_use, residue_sold_DM, Residues_DM, Residues_DM_alt, Residues_wet,
                        grazing_res, flag_no_residue_category_dropped,
                        flag_rpr_match_missing, flag_residue_derived, flag_grazing_residue_allocated)]

saveRDS(res_out, here::here("data", "processed", "01", "impute", "mass_residue.rds"), compress = TRUE)
readr::write_csv(res_out, here::here("data", "processed", "01", "impute", "mass_residue.csv"))
readr::write_csv(as.data.frame(flag_summary(res_out)),
                 here::here("data", "processed", "01", "impute", "mass_residue_flag_summary.csv"))

message("impute/destinations.R: all destination and residue outputs saved.")

# =============================================================================
# TIER 3 ACTIONS / TODO
# =============================================================================
# Tier 3 actions:
# - If any crop/tree disposition repairs depend on cross-section support, move them to tier3_master.R.
# - If residue allocation needs a broader household-level reconciliation, keep the final decision in the master script.
# - Reprofile households that were excluded in the thesis before finalising residue allocation rules.
#
# Outstanding TODO:
# - Confirm all downstream joins use the impute-stage pc and pt outputs, not clean-stage inputs.
# - Check whether pn_crops and pn_trees should be used only as diagnostics or retained as output columns.
# - Decide whether flag_crop_no_production_match should stay as a repair audit or move to tier3_master.R.
# - Decide whether flag_crop_no_disposition_match is a true missingness flag or an exclusion candidate.
# - Review whether flag_crop_yield_missing and flag_crop_area_missing are downstream repair candidates
#   or only diagnostic outputs for later imputation.
# - Confirm that sold/stored/losses zeroing when sale/storage/lost == "no" is a valid structural-zero rule.
# - Check whether the 1.3 threshold in flag_crop_disposition_inconsistent is still defensible.
# - Review whether tree logic needs the same structural-zero and plausibility handling as crops.
# - Confirm whether flag_tree_no_production_match and flag_tree_no_disposition_match should remain
#   in this script or be carried forward as tier3 review items.
# - Check whether flag_tree_ntrees_zero should be treated as a real zero, missingness issue,
#   or a special exclusion review case.
# - Confirm that residue allocation only uses records with a valid residue_use category.
# - Decide whether residue_use == "crop produces no residue" should be retained as a dropped category
#   or flagged earlier in clean stage.
# - Confirm the RPR lookup behaviour when RPR or Dry_matter is missing.
# - Review whether residue_sold_DM should be calculated only when residue_raw is present and numeric.
# - Decide whether grazing_res should remain a direct allocation rule or move into a shared tier3 script.
# - Check whether mass_allcrops should keep residues blank for trees by design.
# - Confirm that flag_no_residue_category_dropped is enough, or whether a separate exclusion flag is needed.
# =============================================================================