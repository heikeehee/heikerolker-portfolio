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

dir.create(here::here("data", "processed", "01", "impute"), showWarnings = FALSE, recursive = TRUE)

pc <- readRDS(here::here("data", "processed", "01", "clean", "pc.rds"))

# ASSUMPTION A1: If planted area is missing but harvested area exists, use harvested area as fallback.
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

# ASSUMPTION A2: Total harvest is observed remaining harvest plus collected quantity.
pc[, total_harvest := harvest_remain + quant_harvest]
pc[, flag_total_harvest_reconciled := fifelse(
  !is.na(harvest_remain) | !is.na(quant_harvest),
  1L,
  0L
)]
n_flag_total_harvest_reconciled <- pc[flag_total_harvest_reconciled == 1L, .N]
message("flag_total_harvest_reconciled: ", n_flag_total_harvest_reconciled,
        " records where total_harvest was constructed from harvest_remain + quant_harvest")

# Recompute harvested-area candidates after imputation
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

# Post-imputation plausibility flag
pc[, flag_area_harvested_gt_plotsize_imp := fifelse(
  area_harvested_com_imp > plotsize_candidate,
  1L,
  0L
)]
n_flag_area_harvested_gt_plotsize_imp <- pc[flag_area_harvested_gt_plotsize_imp == 1L, .N]
message("flag_area_harvested_gt_plotsize_imp: ", n_flag_area_harvested_gt_plotsize_imp,
        " records where imputed/composite harvested area exceeds plotsize_candidate")

# Optional carry-forward flag for downstream use
pc[, flag_area_planted_ha_imputed_or_missing := fifelse(is.na(area_planted_ha_imp), 1L, 0L)]

flag_cols <- names(pc)[grepl("^flag_", names(pc))]
flag_summary <- data.table(
  flag = flag_cols,
  n = vapply(flag_cols, function(col) pc[get(col) == 1L, .N], integer(1))
)[order(-n)]

message("----- Flag summary: pc_imputed -----")
print(flag_summary)

readr::write_csv(
  as.data.frame(flag_summary),
  here::here("data", "processed", "01", "impute", "pc_imputed_flag_summary.csv")
)

saveRDS(
  pc,
  here::here("data", "processed", "01", "impute", "pc_imputed.rds"),
  compress = TRUE
)