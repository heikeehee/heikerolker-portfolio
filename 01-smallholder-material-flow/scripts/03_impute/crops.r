# =============================================================================
# impute/crops.R
# PURPOSE: Apply tier 1 (conversion) and tier 2 (fill) imputations for crop data
# INPUT:   data/processed/01/clean/pc.rds
# OUTPUT:  data/processed/01/impute/pc_imputed.rds
# NOTE:    Tier 1 = unit conversions (kg, liters). Tier 2 = algebraic fill from
#          observed variables. Tier 3 (model-based) goes in impute/tier3_model.R
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "01", "impute"), showWarnings = FALSE, recursive = TRUE)

pc <- readRDS(here::here("data", "processed", "01", "clean", "pc.rds"))

# =============================================================================
# TIER 1: CONVERSION (unit → standard unit: kg for mass)
# =============================================================================
# No tier 1 conversions in this script yet — all crop masses already in kg
# If you add conversion factors later (e.g., baskets → kg), they go here
# Example:
# pc[, harvest_kg := fifelse(unit == "basket", harvest_value * conv_basket_kg, harvest_value)]

# =============================================================================
# TIER 2: FILL (missing but inferable from observed variables)
# =============================================================================

# F1: area_planted_ha fallback — use area_harvested_ha if planted area missing
# Assumption A1: If planted area is missing but harvested area exists, use harvested area
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
n_F1 <- pc[flag_area_planted_ha_imputed == 1L, .N]
message("F1 (area_planted_ha): ", n_F1, " records imputed using area_harvested_ha")

# F2: total_harvest reconciliation — combine observed components
# Assumption A2: Total harvest = remaining harvest + collected quantity
pc[, total_harvest := harvest_remain + quant_harvest]
pc[, flag_total_harvest_reconciled := fifelse(
  !is.na(harvest_remain) | !is.na(quant_harvest),
  1L,
  0L
)]
n_F2 <- pc[flag_total_harvest_reconciled == 1L, .N]
message("F2 (total_harvest): ", n_F2, " records constructed from harvest_remain + quant_harvest")

# =============================================================================
# POST-IMPUTATION DIAGNOSTICS (tier 2 output validation)
# =============================================================================

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

# D1: Plausibility check — imputed area exceeds plot size
pc[, flag_area_harvested_gt_plotsize_imp := fifelse(
  area_harvested_com_imp > plotsize_candidate,
  1L,
  0L
)]
n_D1 <- pc[flag_area_harvested_gt_plotsize_imp == 1L, .N]
message("D1 (area > plotsize): ", n_D1, " records where imputed area exceeds plotsize_candidate")

# D2: Missingness carry-forward (for downstream tier 3 decision)
pc[, flag_area_planted_ha_imputed_or_missing := fifelse(
  is.na(area_planted_ha_imp),
  1L,
  0L
)]

# =============================================================================
# FLAG SUMMARY (all tier 2 + diagnostic flags)
# =============================================================================

flag_cols <- names(pc)[grepl("^flag_", names(pc))]
flag_summary <- data.table(
  flag = flag_cols,
  n = vapply(flag_cols, function(col) pc[get(col) == 1L, .N], integer(1)),
  tier = ifelse(
    flag_cols %in% c("flag_area_planted_ha_imputed", "flag_total_harvest_reconciled"),
    "tier2",
    "diagnostic"
  )
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

message("impute/crops.R: crops imputation complete. ", nrow(pc), " crop records processed.")