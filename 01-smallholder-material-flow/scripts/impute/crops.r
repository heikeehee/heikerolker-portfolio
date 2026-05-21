# =============================================================================
# impute/crops.R
# PURPOSE: Apply assumption-based imputations and reconciliations for crop data
# INPUT:   data/processed/01/clean/pc.rds
# OUTPUT:  data/processed/01/impute/pc_imputed.rds
# NOTE:    This script applies value-changing rules that are intentionally kept
#          out of clean/crops.R so the original missingness remains auditable.
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

# Ensure output directory exists
dir.create(here::here("data", "processed", "01", "impute"), showWarnings = FALSE, recursive = TRUE)

pc <- readRDS(here::here("data", "processed", "01", "clean", "pc.rds"))

# --------------------------------------------------------------------------
# ASSUMPTION A04: If plot exists but planted fraction is missing, use reported
# harvested area as fallback.
# Rationale: This is a value-replacement rule and should not happen in cleaning.
# --------------------------------------------------------------------------
pc[, area_planted_ha_imp := fifelse(
  !is.na(plotnum) & is.na(area_planted) & !is.na(area_harvested_ha),
  area_harvested_ha,
  area_planted_ha
)]

pc[, flag_area_planted_ha_imputed := fifelse(
  !is.na(plotnum) & is.na(area_planted) & !is.na(area_harvested_ha),
  1L,
  0L
)]

n_flag_area_planted_ha_imputed <- pc[flag_area_planted_ha_imputed == 1L, .N]
message("flag_area_planted_ha_imputed: ", n_flag_area_planted_ha_imputed,
        " records where area_planted_ha was replaced using area_harvested_ha")

# --------------------------------------------------------------------------
# ASSUMPTION A05: Total harvest is defined as observed harvested quantity plus
# estimated remaining harvest.
# Rationale: This is a composite inferred field, not a raw survey response.
# --------------------------------------------------------------------------
pc[, total_harvest := harvest_remain + quant_harvest]

# --------------------------------------------------------------------------
# Recompute harvested-area candidates after imputation
# --------------------------------------------------------------------------
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

# --------------------------------------------------------------------------
# Post-imputation plausibility flag
# --------------------------------------------------------------------------
pc[, flag_area_harvested_gt_plotsize_imp := fifelse(
  area_harvested_com_imp > plotsize,
  1L,
  0L
)]

n_flag_area_harvested_gt_plotsize_imp <- pc[flag_area_harvested_gt_plotsize_imp == 1L, .N]
message("flag_area_harvested_gt_plotsize_imp: ", n_flag_area_harvested_gt_plotsize_imp,
        " records where imputed/composite harvested area exceeds plotsize")

saveRDS(
  pc,
  here::here("data", "processed", "01", "impute", "pc_imputed.rds"),
  compress = TRUE
)