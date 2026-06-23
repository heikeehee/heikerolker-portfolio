# =============================================================================
# tier3_master.R
# PURPOSE: Build combined item-level mass-balance sheet, then repair/impute and
#          retain raw vs cleaned vs imputed versions for later comparison.
# GRAIN:   household x item (and related flow keys where available)
# INPUT:   data/processed/01/impute/pc.rds
#          data/processed/01/impute/mass_crops.rds
#          data/processed/01/impute/mass_trees.rds
#          data/processed/01/impute/mass_residue.rds
#          data/processed/01/impute/processed_crops.rds
#          data/processed/01/impute/yieldgaps.rds
#          data/processed/01/households.rds
# OUTPUT:  data/processed/01/tier3_mass_balance_raw.rds
#          data/processed/01/tier3_mass_balance_clean.rds
#          data/processed/01/tier3_mass_balance_imputed.rds
#          data/processed/01/tier3_mass_balance_compare.rds
#          data/processed/01/tier3_mass_balance_flag_summary.csv
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "01"), showWarnings = FALSE, recursive = TRUE)

households <- zap_all(readRDS(here::here("data", "processed", "01", "households.rds")))
pc <- zap_all(readRDS(here::here("data", "processed", "01", "impute", "pc.rds")))
mass_crops <- zap_all(readRDS(here::here("data", "processed", "01", "impute", "mass_crops.rds")))
mass_trees <- zap_all(readRDS(here::here("data", "processed", "01", "impute", "mass_trees.rds")))
mass_residue <- zap_all(readRDS(here::here("data", "processed", "01", "impute", "mass_residue.rds")))
processed_crops <- zap_all(readRDS(here::here("data", "processed", "01", "impute", "processed_crops.rds")))
yieldgaps <- zap_all(readRDS(here::here("data", "processed", "01", "impute", "yieldgaps.rds")))

# Optional inputs if already produced
mass_animals <- if (file.exists(here::here("data", "processed", "01", "impute", "mass_animals.rds"))) {
  zap_all(readRDS(here::here("data", "processed", "01", "impute", "mass_animals.rds")))
} else NULL

mass_hides <- if (file.exists(here::here("data", "processed", "01", "impute", "mass_hides.rds"))) {
  zap_all(readRDS(here::here("data", "processed", "01", "impute", "mass_hides.rds")))
} else NULL

mass_milk <- if (file.exists(here::here("data", "processed", "01", "impute", "mass_milk_final.rds"))) {
  zap_all(readRDS(here::here("data", "processed", "01", "impute", "mass_milk_final.rds")))
} else NULL

mass_eggs <- if (file.exists(here::here("data", "processed", "01", "impute", "mass_eggs.rds"))) {
  zap_all(readRDS(here::here("data", "processed", "01", "impute", "mass_eggs.rds")))
} else NULL

item_groups <- read_csv(
  here::here("data", "reference", "item_groups.csv"),
  na = c("", "NA"),
  show_col_types = FALSE
)

# =============================================================================
# TIER 3A: RAW COMBINED MASS-BALANCE SHEET
# =============================================================================

raw_crops <- pc[, .(
  y4_hhid,
  item_key = as.character(cropid),
  source = "crops",
  harvest_raw = total_harvest,
  area_raw = area_planted_ha_imp,
  harvest_remain_raw = harvest_remain,
  quant_harvest_raw = quant_harvest,
  flag_structural_na_area_planted,
  flag_structural_na_harvest_remain,
  flag_area_planted_ha_imputed,
  flag_total_harvest_reconciled,
  flag_area_planted_ha_imputed_or_missing
)]

raw_crop_dest <- mass_crops[, .(
  y4_hhid,
  item_key = as.character(cropid),
  source = "crop_dest",
  sold_raw = sold,
  consumed_raw = consumed,
  stored_raw = stored,
  seed_raw = seed,
  payment_raw = payment,
  gifts_raw = gifts,
  feed_raw = feed,
  residue_raw = residue,
  smd_raw = smd,
  diff_raw = diff,
  diffp_raw = diffp,
  flag_crop_no_production_match,
  flag_crop_no_disposition_match,
  flag_crop_yield_missing,
  flag_crop_area_missing,
  flag_sold_imputed_zero,
  flag_stored_imputed_zero,
  flag_losses_imputed_zero,
  flag_crop_disposition_inconsistent
)]

raw_tree_dest <- mass_trees[, .(
  y4_hhid,
  item_key = as.character(cropid),
  source = "tree_dest",
  sold_raw = sold,
  consumed_raw = consumed,
  stored_raw = stored,
  losses_raw = losses,
  feed_raw = feed,
  smd_raw = smd,
  diff_raw = diff,
  diffp_raw = diffp,
  flag_tree_no_production_match,
  flag_tree_no_disposition_match,
  flag_tree_yield_missing,
  flag_tree_ntrees_zero,
  flag_tree_disposition_inconsistent
)]

raw_residue <- mass_residue[, .(
  y4_hhid,
  item_key = as.character(cropid),
  source = "residue",
  residue_DM_raw = Residues_DM,
  residue_wet_raw = Residues_wet,
  grazing_res_raw = grazing_res,
  residue_sold_DM_raw = residue_sold_DM,
  flag_rpr_match_missing,
  flag_residue_derived,
  flag_grazing_residue_allocated,
  flag_no_residue_category_dropped
)]

raw_processed <- processed_crops[, .(
  y4_hhid,
  item_key = as.character(crop),
  source = "processed",
  processing_input_raw = sent_to_processing_kg,
  product_raw = product_kg,
  byproduct_raw = byproduct_kg,
  extraction_rate_raw = extraction_rate,
  mass_check_raw = mass_check
)]

raw_yieldgap <- yieldgaps[, .(
  y4_hhid,
  item_key = as.character(cropid),
  source = "yieldgap",
  plotnum_raw = plotnum,
  area_planted_ha_raw = area_planted_ha,
  total_harvest_raw = total_harvest,
  yield_raw = yield,
  YP_raw = YP,
  YG_raw = YG,
  irr_type_raw = irr_type
)]

tier3_raw <- rbindlist(list(
  raw_crops,
  raw_crop_dest,
  raw_tree_dest,
  raw_residue,
  raw_processed,
  raw_yieldgap
), fill = TRUE)

saveRDS(tier3_raw, here::here("data", "processed", "01", "tier3_mass_balance_raw.rds"), compress = TRUE)

# =============================================================================
# TIER 3B: COMBINED MASS-BALANCE HELPERS
# =============================================================================

tier3_mb <- copy(tier3_raw)

tier3_mb[, mb_harvest := fifelse(!is.na(harvest_raw), harvest_raw, NA_real_)]
tier3_mb[, mb_disposition := rowSums(.SD, na.rm = TRUE),
         .SDcols = intersect(c("sold_raw", "consumed_raw", "stored_raw", "seed_raw",
                               "payment_raw", "gifts_raw", "feed_raw", "losses_raw",
                               "residue_raw", "processing_input_raw", "product_raw",
                               "byproduct_raw"), names(tier3_mb))]

tier3_mb[, mb_balance_gap := mb_harvest - mb_disposition]
tier3_mb[, mb_balance_pct := fifelse(mb_harvest > 0, mb_balance_gap / mb_harvest, NA_real_)]
tier3_mb[, mb_has_gap_10 := fifelse(abs(mb_balance_pct) > 0.10, 1L, 0L)]
tier3_mb[, mb_has_gap_50 := fifelse(abs(mb_balance_pct) > 0.50, 1L, 0L)]

# Yield-gap helpers are retained but not forced into the crop disposition balance.
tier3_mb[, yg_balance_gap := fifelse(source == "yieldgap", YG_raw, NA_real_)]
tier3_mb[, yg_negative := fifelse(!is.na(YG_raw) & YG_raw < 0, 1L, 0L)]

saveRDS(tier3_mb, here::here("data", "processed", "01", "tier3_mass_balance_clean.rds"), compress = TRUE)

# =============================================================================
# TIER 3C: REPAIR / IMPUTE
# =============================================================================

tier3_imp <- copy(tier3_mb)

# Placeholder pattern: preserve raw values, create imputed counterparts only where needed.
tier3_imp[, imp_disposition := mb_disposition]
tier3_imp[, imp_balance_gap := mb_balance_gap]
tier3_imp[, imp_balance_pct := mb_balance_pct]
tier3_imp[, imp_yield_gap := ifelse(source == "yieldgap", YG_raw, NA_real_)]

tier3_imp[, cmp_raw_vs_imp_gap := imp_balance_gap - mb_balance_gap]
tier3_imp[, cmp_raw_vs_imp_disposition := imp_disposition - mb_disposition]
tier3_imp[, cmp_raw_vs_imp_yieldgap := imp_yield_gap - yg_balance_gap]

# No silent overwrite of raw values.

# =============================================================================
# TIER 3D: COMPARISON OUTPUT
# =============================================================================

tier3_compare <- tier3_imp[, .(
  y4_hhid,
  item_key,
  source,
  mb_harvest,
  mb_disposition,
  mb_balance_gap,
  mb_balance_pct,
  imp_disposition,
  imp_balance_gap,
  imp_balance_pct,
  yg_balance_gap,
  imp_yield_gap,
  cmp_raw_vs_imp_gap,
  cmp_raw_vs_imp_disposition,
  cmp_raw_vs_imp_yieldgap
)]

saveRDS(tier3_imp, here::here("data", "processed", "01", "tier3_mass_balance_imputed.rds"), compress = TRUE)
saveRDS(tier3_compare, here::here("data", "processed", "01", "tier3_mass_balance_compare.rds"), compress = TRUE)

# =============================================================================
# TIER 3E: FLAG SUMMARY
# =============================================================================

flag_cols <- names(tier3_imp)[grepl("^flag_|^mb_has_gap_|^yg_negative$", names(tier3_imp))]
tier3_flag_summary <- data.table(
  variable = flag_cols,
  n = vapply(flag_cols, function(col) tier3_imp[get(col) == 1L, .N], integer(1))
)[order(-n)]

readr::write_csv(
  tier3_flag_summary,
  here::here("data", "processed", "01", "tier3_mass_balance_flag_summary.csv")
)

message("tier3_master.R: combined raw, clean, imputed, and comparison outputs saved.")