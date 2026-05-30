# =============================================================================
# clean/recall.R
# PURPOSE: Clean household 7-day food consumption recall survey section
# INPUT:   raw$recall from 01_load_raw.R
# OUTPUT:  data/processed/01/clean/recall.rds
#          data/processed/01/clean/recall_flag_summary.csv
#          data/processed/01/clean/recall_missing_conversions.csv
# SECTION: hh_sec_j1 — household Section J1 (food consumption recall)
# NOTE:    Clean stage only. Standardise raw fields, preserve missingness,
#          and flag gaps or contradictions. Do not apply unit conversions,
#          reconcile quantities, or invent conversion factors here.
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "01", "clean"), showWarnings = FALSE, recursive = TRUE)

recall <- raw$recall$hh_sec_j1

# Duplicate keys in raw data
n_flag_dup_recall_keys <- recall %>%
  dplyr::count(y4_hhid, itemcode) %>%
  dplyr::filter(n > 1) %>%
  nrow()
message("flag_dup_recall_keys: ", n_flag_dup_recall_keys,
        " duplicated (y4_hhid, itemcode) combinations detected in raw recall data")

recall <- recall %>%
  clean_up() %>%
  dplyr::rename(
    consumed   = hh_j01,
    quantity   = hh_j02_2,
    unit       = hh_j02_1,
    purchases  = hh_j03_2,
    u_bought   = hh_j03_1,
    value      = hh_j04,
    source     = hh_j04_1,
    production = hh_j05_2,
    u_produced = hh_j05_1,
    gifts      = hh_j06_2,
    u_gifts    = hh_j06_1
  ) %>%
  dplyr::mutate(across(c(unit, u_bought, u_produced, u_gifts), as.character))

recall <- recall %>%
  dplyr::mutate(
    flag_quantity_missing = dplyr::if_else(consumed == "yes" & is.na(quantity), 1L, 0L),
    flag_value_missing = dplyr::if_else(consumed == "yes" & purchases > 0 & is.na(value), 1L, 0L),
    flag_source_missing = dplyr::if_else(consumed == "yes" & purchases > 0 & is.na(source), 1L, 0L),
    flag_consumed_no_but_quantity = dplyr::if_else(consumed == "no" & dplyr::coalesce(quantity, 0) > 0, 1L, 0L),
    flag_unit_missing = dplyr::if_else(consumed == "yes" & quantity > 0 & is.na(unit), 1L, 0L),
    flag_unit_production_missing = dplyr::if_else(consumed == "yes" & production > 0 & is.na(u_produced), 1L, 0L),
    flag_unit_purchases_missing = dplyr::if_else(consumed == "yes" & purchases > 0 & is.na(u_bought), 1L, 0L),
    flag_unit_gifts_missing = dplyr::if_else(consumed == "yes" & gifts > 0 & is.na(u_gifts), 1L, 0L)
  )

missing_conversions <- recall %>%
  dplyr::filter(consumed == "yes") %>%
  dplyr::filter(
    (!is.na(quantity)   & quantity   != 0 & !paste(unit, itemcode) %in% paste(food_conv$unit, food_conv$itemcode)) |
      (!is.na(purchases)  & purchases  != 0 & !paste(u_bought, itemcode) %in% paste(food_conv$unit, food_conv$itemcode)) |
      (!is.na(production) & production != 0 & !paste(u_produced, itemcode) %in% paste(food_conv$unit, food_conv$itemcode)) |
      (!is.na(gifts)      & gifts      != 0 & !paste(u_gifts, itemcode) %in% paste(food_conv$unit, food_conv$itemcode))
  ) %>%
  dplyr::distinct(itemcode, unit, .keep_all = TRUE) %>%
  dplyr::select(itemcode, unit, starts_with("u_"),
                quantity, purchases, production, gifts)

readr::write_csv(
  missing_conversions,
  here::here("data", "processed", "01", "clean", "recall_missing_conversions.csv")
)

flag_cols <- names(recall)[grepl("^flag_", names(recall))]
flag_summary <- data.table(
  flag = flag_cols,
  n = vapply(flag_cols, function(col) recall[get(col) == 1L, .N], integer(1))
)[order(-n)]

message("----- Flag summary: recall -----")
print(flag_summary)

readr::write_csv(
  as.data.frame(flag_summary),
  here::here("data", "processed", "01", "clean", "recall_flag_summary.csv")
)

saveRDS(recall, here::here("data", "processed", "01", "clean", "recall.rds"), compress = TRUE)
message("clean/recall.R: recall data cleaned and saved")