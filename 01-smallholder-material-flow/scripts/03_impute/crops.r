# =============================================================================
# impute/crops.R
# PURPOSE: Apply tier 1 (conversion) and tier 2 (fill) imputations for crop data
# INPUT: data/processed/01/clean/pc.rds
# OUTPUT: data/processed/01/impute/pc_imputed.rds
# NOTE: Tier 1 = unit conversions. Tier 2 = algebraic fill from observed values.
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "01", "impute"), showWarnings = FALSE, recursive = TRUE)

pc <- readRDS(here::here("data", "processed", "01", "clean", "pc.rds"))

# =============================================================================
# TIER 1: STRUCTURAL ZERO / CONVERSION LOGIC
# =============================================================================

pc[, flag_structural_na_area_planted := fifelse(
  !is.na(plotnum) & is.na(area_planted) & is.na(area_planted_ha) & is.na(area_harvested_ha),
  1L,
  0L
)]

pc[, flag_structural_na_harvest_remain := fifelse(
  !is.na(plotnum) & lessharvest == "no" & is.na(harvest_remain),
  1L,
  0L
)]

pc[flag_structural_na_area_planted == 1L & is.na(area_planted_ha), area_planted_ha := 0]
pc[flag_structural_na_harvest_remain == 1L & is.na(harvest_remain), harvest_remain := 0]

n_struct_area <- pc[flag_structural_na_area_planted == 1L, .N]
n_struct_harvest <- pc[flag_structural_na_harvest_remain == 1L, .N]
message("structural NA area_planted: ", n_struct_area, " records set up for zero/repair logic")
message("structural NA harvest_remain: ", n_struct_harvest, " records set up for zero/repair logic")

# =============================================================================
# TIER 2: FILL / RECONCILIATION
# =============================================================================

pc[, area_planted_ha_imp := fifelse(
  !is.na(plotnum) & is.na(area_planted_ha) & !is.na(area_harvested_ha),
  area_harvested_ha,
  area_planted_ha
)]
pc[, flag_area_planted_ha_imputed := fifelse(
  !is.na(plotnum) & is.na(area_planted_ha) & !is.na(area_harvested_ha),
  1L,
  0L
)]
n_area_planted <- pc[flag_area_planted_ha_imputed == 1L, .N]
message("flag_area_planted_ha_imputed: ", n_area_planted, " records imputed using area_harvested_ha")

pc[, area_not_harvested_ha := fifelse(
  harvested == "no" & !is.na(area_planted_ha_imp),
  as.numeric(area_planted_ha_imp),
  NA_real_
)]
pc[, flag_not_harvested := fifelse(
  harvested == "no",
  1L, 0L
)]
message("flag_not_harvested: ",
        pc[flag_not_harvested == 1L, .N],
        " plot-crop record(s) with no harvest — area recorded, loss deferred")

pc[, total_harvest := harvest_remain + quant_harvest]
pc[, flag_total_harvest_reconciled := fifelse(
  !is.na(harvest_remain) | !is.na(quant_harvest),
  1L,
  0L
)]

n_total_harvest <- pc[flag_total_harvest_reconciled == 1L, .N]
message("flag_total_harvest_reconciled: ", n_total_harvest, " records constructed from harvest_remain + quant_harvest")

pc[, area_harvested_final_imp := ifelse(
  lessharvest == "no" & is.na(harvest_remain),
  area_planted_ha_imp,
  NA_real_
)]

pc[, area_harvested_com_imp := ifelse(
  lessharvest == "no" & is.na(harvest_remain),
  area_planted_ha_imp,
  area_harvested_alt
)]

pc[, flag_area_harvested_gt_plotsize_imp := fifelse(
  !is.na(area_harvested_com_imp) & !is.na(plotsize_candidate) & area_harvested_com_imp > plotsize_candidate,
  1L,
  0L
)]

pc[, flag_area_planted_ha_imputed_or_missing := fifelse(
  is.na(area_planted_ha_imp),
  1L,
  0L
)]


# Single-record contradiction: finished == "no" but end_harvest is recorded
# Decision: harvest is complete, harvest_remain is a true zero
pc[, flag_harvest_remain_contradiction := fifelse(
  finished == "no" & !is.na(end_harvest) & is.na(harvest_remain),
  1L, 0L
)]

pc[flag_harvest_remain_contradiction == 1L, harvest_remain := 0]

message("flag_harvest_remain_contradiction: ",
        pc[flag_harvest_remain_contradiction == 1L, .N],
        " record(s) where finished == 'no' but end_harvest recorded — harvest_remain set to 0")

saveRDS(pc, here::here("data", "processed", "01", "impute", "pc_imputed.rds"), compress = TRUE)

# =============================================================================
# SECTION 2B: TREE IMPUTATION / RECONCILIATION
# =============================================================================

pt <- readRDS(here::here("data", "processed", "01", "clean", "pt.rds"))

pt_imputed <- copy(pt)

# Standardize tree harvest field
pt_imputed[, total_harvest := as.numeric(harvest)]

# Area is not relevant for trees in the same way as crops; keep keys and harvest only.
# Preserve pre-lost / loss_cause for downstream audit.
pt_imputed[, flag_tree_harvest_missing := fifelse(!is.na(plotnum) & is.na(harvest), 1L, 0L)]
pt_imputed[, flag_tree_ntrees_zero := fifelse(!is.na(ntrees) & ntrees == 0, 1L, 0L)]

message("flag_tree_harvest_missing: ", pt_imputed[flag_tree_harvest_missing == 1L, .N])
message("flag_tree_ntrees_zero: ", pt_imputed[flag_tree_ntrees_zero == 1L, .N])

saveRDS(pt_imputed,
        here::here("data", "processed", "01", "impute", "pt_imputed.rds"),
        compress = TRUE)


# =============================================================================
# SECTION 3: JOIN CROPS AND TREES AT ROW LEVEL
# Keep plot-level detail here only.
# =============================================================================

pc_imp <- readRDS(here::here("data", "processed", "01", "impute", "pc_imputed.rds"))
pt_imp <- readRDS(here::here("data", "processed", "01", "impute", "pt_imputed.rds"))

# Standardize the tree records to match crop keys as much as possible.
pt_imp[, `:=`(
  area_planted_ha = NA_real_,
  area_harvested_ha = NA_real_,
  harvest_remain = NA_real_,
  quant_harvest = NA_real_,
  preharvest_losses = NA_character_,
  lessharvest = NA_character_,
  harvested = NA_character_,
  area_harvested_alt = NA_real_,
  area_harvested_final_imp = NA_real_,
  area_harvested_com_imp = NA_real_,
  area_planted_ha_imp = NA_real_,
  total_harvest = as.numeric(total_harvest)
)]

# Keep plot provenance in Section 3 only.
pc_rows <- pc_imp[, .(
  y4_hhid = as.character(y4_hhid),
  plotnum = as.character(plotnum),
  cropid = as.character(cropid),
  type = as.character(type),
  item_type = "crop",
  area_planted_ha = as.numeric(area_planted_ha),
  area_planted_ha_imp = as.numeric(area_planted_ha_imp),
  area_harvested_ha = as.numeric(area_harvested_ha),
  area_harvested_alt = as.numeric(area_harvested_alt),
  area_harvested_final_imp = as.numeric(area_harvested_final_imp),
  area_harvested_com_imp = as.numeric(area_harvested_com_imp),
  harvest_remain = as.numeric(harvest_remain),
  quant_harvest = as.numeric(quant_harvest),
  total_harvest = as.numeric(total_harvest),
  pre_lost = as.character(preharvest_losses),
  loss_cause = as.character(loss_cause),
  harvested = as.character(harvested),
  lessharvest = as.character(lessharvest),
  ntrees = as.numeric(NA),
  flag_structural_na_area_planted = as.integer(flag_structural_na_area_planted),
  flag_structural_na_harvest_remain = as.integer(flag_structural_na_harvest_remain),
  flag_area_planted_ha_imputed = as.integer(flag_area_planted_ha_imputed),
  flag_total_harvest_reconciled = as.integer(flag_total_harvest_reconciled),
  flag_area_harvested_gt_plotsize_imp = as.integer(flag_area_harvested_gt_plotsize_imp),
  flag_area_planted_ha_imputed_or_missing = as.integer(flag_area_planted_ha_imputed_or_missing),
  flag_tree_harvest_missing = as.integer(NA),
  flag_tree_ntrees_zero = as.integer(NA)
)]

pt_rows <- pt_imp[, .(
  y4_hhid = as.character(y4_hhid),
  plotnum = as.character(plotnum),
  cropid = as.character(cropid),
  type = as.character(type),
  item_type = "tree",
  area_planted_ha = as.numeric(NA),
  area_planted_ha_imp = as.numeric(NA),
  area_harvested_ha = as.numeric(NA),
  area_harvested_alt = as.numeric(NA),
  area_harvested_final_imp = as.numeric(NA),
  area_harvested_com_imp = as.numeric(NA),
  harvest_remain = as.numeric(NA),
  quant_harvest = as.numeric(NA),
  total_harvest = as.numeric(total_harvest),
  pre_lost = as.character(pre_lost),
  loss_cause = as.character(loss_cause),
  harvested = as.character(NA),
  lessharvest = as.character(NA),
  ntrees = as.numeric(ntrees),
  flag_structural_na_area_planted = as.integer(NA),
  flag_structural_na_harvest_remain = as.integer(NA),
  flag_area_planted_ha_imputed = as.integer(NA),
  flag_total_harvest_reconciled = as.integer(NA),
  flag_area_harvested_gt_plotsize_imp = as.integer(NA),
  flag_area_planted_ha_imputed_or_missing = as.integer(NA),
  flag_tree_harvest_missing = as.integer(flag_tree_harvest_missing),
  flag_tree_ntrees_zero = as.integer(flag_tree_ntrees_zero)
)]

crop_tree_rows <- rbindlist(list(pc_rows, pt_rows), fill = TRUE)

saveRDS(
  crop_tree_rows,
  here::here("data", "processed", "01", "impute", "crop_tree_rows.rds"),
  compress = TRUE
)

# =============================================================================
# SECTION 4: COLLAPSE TO HOUSEHOLD X ITEM
# Generate final imputation flags at collapsed grain.
# Plot provenance is dropped here.
# =============================================================================

# Harmonize item-level keys
crop_tree_rows[, item := as.character(cropid)]
crop_tree_rows[, item_type := fifelse(!is.na(ntrees), "tree", "crop")]

# Normalize numeric fields for collapse
crop_tree_rows[, harvest_use := fifelse(!is.na(total_harvest), total_harvest, NA_real_)]
crop_tree_rows[, area_use := fifelse(!is.na(area_planted_ha_imp), area_planted_ha_imp, NA_real_)]

# Collapse to household x item
collapse_dt <- crop_tree_rows[, .(
  item_type = first(na.omit(item_type)),
  type = first(na.omit(type)),
  total_harvest = sum(harvest_use, na.rm = TRUE),
  area_planted_ha = sum(area_use, na.rm = TRUE),
  ntrees = sum(ntrees, na.rm = TRUE),
  plotnum_n = uniqueN(plotnum),
  prelost_yes_n = sum(tolower(as.character(pre_lost)) == "yes", na.rm = TRUE),
  loss_cause = {
    x <- unique(na.omit(as.character(loss_cause)))
    if (length(x) == 0) NA_character_ else paste(sort(x), collapse = "; ")
  },
  quant_harvest = sum(quant_harvest, na.rm = TRUE),
  harvest_remain = sum(harvest_remain, na.rm = TRUE),
  flag_structural_na_area_planted_n = sum(flag_structural_na_area_planted == 1L, na.rm = TRUE),
  flag_structural_na_harvest_remain_n = sum(flag_structural_na_harvest_remain == 1L, na.rm = TRUE),
  flag_area_planted_ha_imputed_n = sum(flag_area_planted_ha_imputed == 1L, na.rm = TRUE),
  flag_total_harvest_reconciled_n = sum(flag_total_harvest_reconciled == 1L, na.rm = TRUE),
  flag_area_harvested_gt_plotsize_imp_n = sum(flag_area_harvested_gt_plotsize_imp == 1L, na.rm = TRUE),
  flag_area_planted_ha_imputed_or_missing_n = sum(flag_area_planted_ha_imputed_or_missing == 1L, na.rm = TRUE),
  flag_tree_harvest_missing_n = sum(flag_tree_harvest_missing == 1L, na.rm = TRUE),
  flag_tree_ntrees_zero_n = sum(flag_tree_ntrees_zero == 1L, na.rm = TRUE)
), by = .(y4_hhid, item)]

collapse_dt[, loss_cause := fifelse(prelost_yes_n = 0, "no loss", loss_cause)]

# Final collapsed flags
collapse_dt[, flag_any_imputation := fifelse(
  flag_area_planted_ha_imputed_n > 0 | flag_total_harvest_reconciled_n > 0 |
    flag_tree_harvest_missing_n > 0,
  1L, 0L
)]

collapse_dt[, flag_any_plausibility := fifelse(
  flag_area_harvested_gt_plotsize_imp_n > 0 | flag_tree_ntrees_zero_n > 0,
  1L, 0L
)]

collapse_dt[, flag_prelost_any := fifelse(prelost_yes_n > 0, 1L, 0L)]

# Flag shell records: household appears but has no cropid at all
collapse_dt[, flag_shell_record := fifelse(is.na(item) | item == "NA", 1L, 0L)]

# Final household x item output
crops_final <- collapse_dt[
  , .(
    y4_hhid,
    item,
    item_type,
    type,
    harvest,
    area_planted_ha,
    ntrees,
    prelost_yes_n,
    loss_cause,
    quant_harvest,
    harvest_remain,
    flag_any_imputation,
    flag_any_plausibility,
    flag_structural_na_area_planted_n,
    flag_structural_na_harvest_remain_n,
    flag_area_planted_ha_imputed_n,
    flag_total_harvest_reconciled_n,
    flag_area_harvested_gt_plotsize_imp_n,
    flag_area_planted_ha_imputed_or_missing_n,
    flag_tree_harvest_missing_n,
    flag_tree_ntrees_zero_n,
    flag_shell_record,
    flag_prelost_any
  )
]

saveRDS(
  crops_final,
  here::here("data", "processed", "01", "impute", "crops_imputed_hh_item.rds"),
  compress = TRUE
)

# =============================================================================
# FLAG SUMMARY
# =============================================================================

flag_cols <- names(pc)[grepl("^flag_", names(pc))]

flag_summary <- data.table(
  Variable = flag_cols,
  Script = "impute/crops.R",
  Type = fifelse(
    flag_cols %in% c("flag_structural_na_area_planted", "flag_structural_na_harvest_remain"),
    "diagnostic",
    fifelse(
      flag_cols %in% c("flag_area_planted_ha_imputed", "flag_total_harvest_reconciled"),
      "fill",
      "diagnostic"
    )
  ),
  Description = fifelse(
    flag_cols == "flag_structural_na_area_planted", "Structural NA check for planted area",
    fifelse(
      flag_cols == "flag_structural_na_harvest_remain", "Structural NA check for harvest remaining",
      fifelse(
        flag_cols == "flag_area_planted_ha_imputed", "area_planted_ha filled from area_harvested_ha",
        fifelse(
          flag_cols == "flag_total_harvest_reconciled", "total_harvest reconstructed from harvest_remain + quant_harvest",
          fifelse(
            flag_cols == "flag_area_harvested_gt_plotsize_imp", "Imputed/composite harvested area exceeds plotsize_candidate",
            fifelse(
              flag_cols == "flag_area_planted_ha_imputed_or_missing", "area_planted_ha_imp remains missing",
              "Diagnostic flag"
            )
          )
        )
      )
    )
  ),
  Tier = fifelse(
    flag_cols %in% c("flag_area_planted_ha_imputed", "flag_total_harvest_reconciled"),
    "tier2",
    "diagnostic"
  ),
  Method = fifelse(
    flag_cols == "flag_area_planted_ha_imputed", "fallback to harvested area",
    fifelse(
      flag_cols == "flag_total_harvest_reconciled", "algebraic reconstruction",
      fifelse(
        flag_cols == "flag_structural_na_area_planted", "set to zero where survey logic requires",
        fifelse(
          flag_cols == "flag_structural_na_harvest_remain", "set to zero where survey logic requires", # at plot level!
          fifelse(
            flag_cols == "flag_area_harvested_gt_plotsize_imp", "post-imputation plausibility check",
            fifelse(
              flag_cols == "flag_area_planted_ha_imputed_or_missing", "carry-forward diagnostic",
              "diagnostic"
            )
          )
        )
      )
    )
  ),
  Status = "implemented",
  Notes = fifelse(
    flag_cols == "flag_area_planted_ha_imputed", "Keep if this later feeds Tier 3 yield logic",
    fifelse(
      flag_cols == "flag_total_harvest_reconciled", "Used downstream in yield and mass balance work",
      fifelse(
        flag_cols == "flag_area_harvested_gt_plotsize_imp", "Review for implausibility before retention decisions",
        ""
      )
    )
  ),
  n = vapply(flag_cols, function(col) pc[get(col) == 1L, .N], integer(1))
)[order(-n)]

message("----- Flag summary: pc_imputed -----")
print(flag_summary)

# =============================================================================
# TIER 3 ACTIONS / TODO
# =============================================================================
# - logic behind loss_cause at household level
# Tier 3 actions:
# - If crop-specific yield or gap logic is added here, keep it at the very end.
# - If yield gap depends on multiple sections, move it to tier3_master.R.
# - Re-check any households previously excluded in the thesis before final Tier 3 logic.
# - Profile records that remain missing after Tier 2 to see whether Tier 3 is defensible.
# 
# Outstanding TODO:
# - Standardise on area_planted_ha everywhere; remove any remaining area_planted references.
# - Confirm whether area_planted_ha_imp should be numeric before fifelse() calls.
# - Decide whether flag_gps_area_zero belongs in this script or in clean/crops.R only.
# - Decide whether flag_harvest_contradiction should stay clean-only or be promoted to impute.
# - Check whether flag_plotnum_missing can stay resolved in clean and be removed here.
# - Merge or drop duplicate harvested-area plausibility flags:
#   flag_area_harvested_gt_plotsize vs flag_area_harvested_gt_plotsize_imp.
# - Review whether flag_area_planted_missing, flag_harvest_missing,
#   flag_harvest_remain_missing, and flag_quant_harvest_missing are all needed
#   separately or can be collapsed into one harvest-availability audit.
# - Check that structural NA logic is only converting true structural zeros,
#   not accidentally imputing legitimate missing values.
# - Verify that total_harvest reconstruction is the only Tier 2 rule for harvest totals.
# - Confirm that the flag summary includes only the final kept flags.
# =============================================================================