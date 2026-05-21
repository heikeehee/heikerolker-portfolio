# =============================================================================
# impute/recall.R
# PURPOSE: Apply assumption-based imputations and reconciliations for recall data
# INPUT:   data/processed/01/clean/recall.rds
# OUTPUT:  data/processed/01/impute/recall_imputed.rds
# NOTE:    This script contains value-changing rules only.
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "01", "impute"), showWarnings = FALSE, recursive = TRUE)

recall <- readRDS(here::here("data", "processed", "01", "clean", "recall.rds"))

# ASSUMPTION A1: If quantity is missing but a unit-specific conversion exists,
# no value repair is made here; this remains a clean-stage gap unless a donor value
# is explicitly defined later.

# ASSUMPTION A2: Where raw quantity is 0 but unit is missing, treat as zero-acquisition.
recall[, flag_zero_without_unit := fifelse(quantity == 0 & is.na(unit), 1L, 0L)]
n_flag_zero_without_unit <- sum(recall$flag_zero_without_unit, na.rm = TRUE)
message("flag_zero_without_unit: ", n_flag_zero_without_unit,
        " rows where quantity == 0 and unit is missing")

# ASSUMPTION A3: If total acquisition should be represented as a single field,
# use the cleaned component fields to construct it here.
recall[, total_acquisition_kg := rowSums(.SD, na.rm = TRUE), .SDcols = c("purchases_kg", "production_kg", "gifts_kg")]
recall[, flag_total_acquisition_constructed := fifelse(!is.na(total_acquisition_kg), 1L, 0L)]
n_flag_total_acquisition_constructed <- sum(recall$flag_total_acquisition_constructed, na.rm = TRUE)
message("flag_total_acquisition_constructed: ", n_flag_total_acquisition_constructed,
        " rows where total_acquisition_kg was constructed")

# ASSUMPTION A4: Reconcile reported quantity with component-based acquisition when needed.
recall[, quantity_reconciled_kg := fifelse(
  is.na(quantity_kg) & !is.na(total_acquisition_kg),
  total_acquisition_kg,
  quantity_kg
)]
recall[, flag_quantity_reconciled := fifelse(is.na(quantity_kg) & !is.na(total_acquisition_kg), 1L, 0L)]
n_flag_quantity_reconciled <- sum(recall$flag_quantity_reconciled, na.rm = TRUE)
message("flag_quantity_reconciled: ", n_flag_quantity_reconciled,
        " rows where missing quantity_kg was replaced using total_acquisition_kg")

# ASSUMPTION A5: If a stricter matched value is required, compare before overwriting.
recall[, flag_quantity_reconciled_mismatch := fifelse(
  !is.na(quantity_kg) & !is.na(total_acquisition_kg) & abs(quantity_kg - total_acquisition_kg) > 0.001,
  1L,
  0L
)]
n_flag_quantity_reconciled_mismatch <- sum(recall$flag_quantity_reconciled_mismatch, na.rm = TRUE)
message("flag_quantity_reconciled_mismatch: ", n_flag_quantity_reconciled_mismatch,
        " rows where quantity_kg differs from total_acquisition_kg")

# =============================================================================
# FLAG SUMMARY
# =============================================================================

flag_cols <- names(recall)[grepl("^flag_", names(recall))]
flag_summary <- data.table(
  flag = flag_cols,
  n = vapply(flag_cols, function(col) recall[get(col) == 1L, .N], integer(1))
)[order(-n)]

message("----- Flag summary: recall_imputed -----")
print(flag_summary)

readr::write_csv(
  as.data.frame(flag_summary),
  here::here("data", "processed", "01", "impute", "recall_flag_summary.csv")
)

saveRDS(recall, here::here("data", "processed", "01", "impute", "recall_imputed.rds"), compress = TRUE)
message("impute/recall.R: recall data imputed and saved")