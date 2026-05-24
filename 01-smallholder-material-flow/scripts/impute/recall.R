# =============================================================================
# impute/recall.R
# PURPOSE: Apply unit conversion and reconciliation rules for recall data
# INPUT:   data/processed/01/clean/recall.rds
# OUTPUT:  data/processed/01/impute/recall_imputed.rds
#          data/processed/01/impute/recall_flag_summary.csv
# NOTE:    This script contains value-changing rules only.
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "01", "impute"), showWarnings = FALSE, recursive = TRUE)

KG_PER_GRAM <- 0.001

food_conv <- tibble::tribble(
  ~unit,        ~itemcode,                                                ~conv,
  "litre",      "fresh milk",                                             1.08,
  "pieces",     "eggs",                                                   0.0408,
  "litre",      "milk products (like cream, cheese, yoghurt etc)",        1.01,
  "litre",      "cooking oil",                                            0.9,
  "litre",      "bottled/canned soft drinks (soda, juice, water)",        1,
  "litre",      "bottled beer",                                           1,
  "litre",      "local brews",                                            1,
  "litre",      "honey, syrups, jams, marmalade, jellies, canned fruits", 1.43,
  "litre",      "buns, cakes and biscuits",                               0.02,
  "pieces",     "bread",                                                  0.5,
  "pieces",     "coconuts (mature/immature)",                             0.8,
  "pieces",     "sweets",                                                 0.05,
  "millilitre", "cooking oil",                                            0.001,
  "millilitre", "fresh milk",                                             0.001,
  "millilitre", "milk products (like cream, cheese, yoghurt etc)",        0.001,
  "millilitre", "bottled/canned soft drinks (soda, juice, water)",        0.001,
  "millilitre", "honey, syrups, jams, marmalade, jellies, canned fruits", 1.001,
  "millilitre", "wine and spirits",                                       0.001,
  "millilitre", "bottled beer",                                           0.001,
  "millilitre", "local brews",                                            0.001,
  "millilitre", "prepared tea, coffee",                                   0.001,
  "millilitre", "peas, beans, lentils and other pulses",                  0.001,
  "pieces",     "bottled/canned soft drinks (soda, juice, water)",        0.355,
  "litre",      "butter, margarine, ghee and other fat products",         0.959,
  "litre",      "sweet potatoes",                                         0.66,
  "litre",      "canned, dried and wild vegetables",                      0.3,
  "pieces",     "buns, cakes and biscuits",                               0.1
)

unique_items <- unique(food_conv$itemcode)
food_conv <- dplyr::bind_rows(
  food_conv,
  tibble::tibble(unit = rep("kilograms", length(unique_items)), itemcode = unique_items, conv = 1),
  tibble::tibble(unit = rep("grams", length(unique_items)), itemcode = unique_items, conv = KG_PER_GRAM)
) %>%
  dplyr::distinct()

convert_to_kg <- function(df, qty_col, unit_col, items_ref) {
  df %>%
    dplyr::left_join(
      dplyr::distinct(items_ref, itemcode, unit, .keep_all = TRUE),
      by = c("itemcode", setNames("unit", unit_col))
    ) %>%
    dplyr::mutate(
      "{qty_col}_kg" := dplyr::case_when(
        is.na(.data[[qty_col]])                          ~ NA_real_,
        .data[[qty_col]] == 0 & is.na(.data[[unit_col]]) ~ 0,
        .data[[unit_col]] == "kilograms"                ~ .data[[qty_col]],
        .data[[unit_col]] == "grams"                    ~ .data[[qty_col]] * KG_PER_GRAM,
        !is.na(conv)                                     ~ .data[[qty_col]] * conv,
        TRUE                                             ~ NA_real_
      )
    ) %>%
    dplyr::select(-conv)
}

recall <- readRDS(here::here("data", "processed", "01", "clean", "recall.rds"))

recall_kg <- recall %>%
  convert_to_kg("quantity",   "unit",       food_conv) %>%
  convert_to_kg("purchases",  "u_bought",   food_conv) %>%
  convert_to_kg("production", "u_produced", food_conv) %>%
  convert_to_kg("gifts",      "u_gifts",    food_conv)

recall_kg <- recall_kg %>%
  dplyr::mutate(
    flag_zero_without_unit = dplyr::if_else(quantity == 0 & is.na(unit), 1L, 0L),
    flag_total_acquisition_constructed = dplyr::if_else(
      !is.na(purchases_kg) | !is.na(production_kg) | !is.na(gifts_kg), 1L, 0L
    ),
    total_acquisition_kg = rowSums(dplyr::across(c(purchases_kg, production_kg, gifts_kg)), na.rm = TRUE),
    quantity_reconciled_kg = dplyr::if_else(
      is.na(quantity_kg) & !is.na(total_acquisition_kg),
      total_acquisition_kg,
      quantity_kg
    ),
    flag_quantity_reconciled = dplyr::if_else(is.na(quantity_kg) & !is.na(total_acquisition_kg), 1L, 0L),
    flag_quantity_reconciled_mismatch = dplyr::if_else(
      !is.na(quantity_kg) & !is.na(total_acquisition_kg) & abs(quantity_kg - total_acquisition_kg) > 0.001,
      1L, 0L
    )
  )

missing_conversions <- recall_kg %>%
  dplyr::filter(consumed == "yes") %>%
  dplyr::filter(
    (!is.na(quantity)   & quantity   != 0 & is.na(quantity_kg)) |
      (!is.na(purchases)  & purchases  != 0 & is.na(purchases_kg)) |
      (!is.na(production) & production != 0 & is.na(production_kg)) |
      (!is.na(gifts)      & gifts      != 0 & is.na(gifts_kg))
  )

flag_cols <- names(recall_kg)[grepl("^flag_", names(recall_kg))]
flag_summary <- data.table(
  flag = flag_cols,
  n = vapply(flag_cols, function(col) recall_kg[get(col) == 1L, .N], integer(1))
)[order(-n)]

message("----- Flag summary: recall_imputed -----")
print(flag_summary)

readr::write_csv(
  as.data.frame(flag_summary),
  here::here("data", "processed", "01", "impute", "recall_flag_summary.csv")
)

saveRDS(recall_kg, here::here("data", "processed", "01", "impute", "recall_imputed.rds"), compress = TRUE)
message("impute/recall.R: recall data imputed and saved")