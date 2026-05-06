# =============================================================================
# clean/recall.R
# PURPOSE: Clean household 7-day food consumption recall survey section
# INPUT:   raw$recall from 01_load_raw.R
# OUTPUT:  data/processed/clean/recall.rds
# SECTION: hh_sec_j1 — household Section J1 (food consumption recall)
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "01", "clean"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# CONSTANTS
# =============================================================================

KG_PER_GRAM <- 0.001

# =============================================================================
# CONVERSION REFERENCE TABLE
# Maps (itemcode, unit) → conversion factor to kg
# Sources: product-specific densities from literature (see inline comments)
# =============================================================================

# ASSUMPTION: All conversion factors below are assumed from literature or
# standard density references, NOT from the LSMS codebook directly.
# Most conversion factors are derived from a US conversion website
food_conv <- tibble::tribble(
  ~unit,         ~itemcode,                                                     ~conv,
  "litre",       "fresh milk",                                                  1.08,
  "pieces",      "eggs",                                                        0.0408, # average weight TZA
  "litre",       "milk products (like cream, cheese, yoghurt etc)",             1.01,
  "litre",       "cooking oil",                                                 0.9,
  "litre",       "bottled/canned soft drinks (soda, juice, water)",             1,
  "litre",       "bottled beer",                                                1,
  "litre",       "local brews",                                                 1,
  "litre",       "honey, syrups, jams, marmalade, jellies, canned fruits",     1.43,
  "litre",       "buns, cakes and biscuits",                                    0.02,
  "pieces",      "bread",                                                       0.5,
  "pieces",      "coconuts (mature/immature)",                                  0.8,
  "pieces",      "sweets",                                                      0.05,
  "millilitre",  "cooking oil",                                                 0.001,
  "millilitre",  "fresh milk",                                                  0.001,
  "millilitre",  "milk products (like cream, cheese, yoghurt etc)",             0.001,
  "millilitre",  "bottled/canned soft drinks (soda, juice, water)",             0.001,
  "millilitre",  "honey, syrups, jams, marmalade, jellies, canned fruits",     0.001,
  "millilitre",  "wine and spirits",                                            0.001,
  "millilitre",  "bottled beer",                                                0.001,
  "millilitre",  "local brews",                                                 0.001,
  "millilitre",  "prepared tea, coffee",                                        0.001,
  "millilitre",  "peas, beans, lentils and other pulses",                       0.001,
  "pieces",      "bottled/canned soft drinks (soda, juice, water)",             0.355,
  "litre",       "butter, margarine, ghee and other fat products",              0.959,
  "litre",       "sweet potatoes",                                              0.66,
  "litre",       "canned, dried and wild vegetables",                           0.3,
  "pieces",      "buns, cakes and biscuits",                                    0.1 # guess
)

# Append kg (identity) and gram conversions for every item
unique_items <- unique(food_conv$itemcode)

food_conv <- dplyr::bind_rows(
  food_conv,
  tibble::tibble(
    unit     = rep("kilograms", length(unique_items)),
    itemcode = unique_items,
    conv     = 1
  ),
  tibble::tibble(
    unit     = rep("grams", length(unique_items)),
    itemcode = unique_items,
    conv     = KG_PER_GRAM
  )
) %>%
  dplyr::distinct()

# =============================================================================
# LOAD AND RENAME
# =============================================================================

recall <- raw$recall$hh_sec_j1

recall <- recall %>%
  clean_up() %>%
  dplyr::rename(
    consumed   = hh_j01,
    quantity   = hh_j02_2,  unit       = hh_j02_1,
    purchases  = hh_j03_2,  u_bought   = hh_j03_1,
    value      = hh_j04,    source     = hh_j04_1,
    production = hh_j05_2,  u_produced = hh_j05_1,
    gifts      = hh_j06_2,  u_gifts    = hh_j06_1
  ) %>%
  dplyr::mutate(across(c(unit, u_bought, u_produced, u_gifts), as.character))

# =============================================================================
# UNIT CONVERSION: all quantity columns → kilograms
# =============================================================================

convert_to_kg <- function(df, qty_col, unit_col, items_ref) {
  df %>%
    dplyr::left_join(
      dplyr::distinct(items_ref, itemcode, unit, .keep_all = TRUE),
      by = c("itemcode", setNames("unit", unit_col))
    ) %>%
    dplyr::mutate(
      "{qty_col}_kg" := dplyr::case_when(
        is.na(.data[[qty_col]])                          ~ NA_real_,          # source not reported — not a conversion failure
        .data[[qty_col]] == 0 & is.na(.data[[unit_col]]) ~ 0,                # structural zero — unit not recorded
        .data[[unit_col]] == "kilograms"                 ~ .data[[qty_col]],
        .data[[unit_col]] == "grams"                     ~ .data[[qty_col]] * KG_PER_GRAM,
        !is.na(conv)                                     ~ .data[[qty_col]] * conv,
        TRUE                                             ~ NA_real_           # genuine missing conversion — flag upstream
      )
    ) %>%
    dplyr::select(-conv) #, -all_of(unit_col)
}

recall_kg <- recall %>%
  convert_to_kg("quantity",   "unit",       food_conv) %>%
  convert_to_kg("purchases",  "u_bought",   food_conv) %>%
  convert_to_kg("production", "u_produced", food_conv) %>%
  convert_to_kg("gifts",      "u_gifts",    food_conv)

# =============================================================================
# DIAGNOSTIC: report unmatched item/unit combinations
# =============================================================================

missing_conversions <- recall_kg %>%
  dplyr::filter(consumed == "yes") %>%
  dplyr::filter(
    (!is.na(quantity)   & quantity   != 0 & is.na(quantity_kg))   |
      (!is.na(purchases)  & purchases  != 0 & is.na(purchases_kg))  |
      (!is.na(production) & production != 0 & is.na(production_kg)) |
      (!is.na(gifts)      & gifts      != 0 & is.na(gifts_kg))
  ) %>%
  dplyr::distinct(itemcode, unit, .keep_all = TRUE) %>%
  dplyr::select(itemcode, unit, starts_with("u_"),
                quantity, quantity_kg,
                purchases, purchases_kg,
                production, production_kg,
                gifts, gifts_kg)

if (nrow(missing_conversions) > 0) {
  # 🚩 FLAG UNIT: Genuine missing conversion factors detected.
  # Scope: consumed == "yes"; structural zeros and unreported quantities excluded.
  # No action this requires imputation.
  message("clean/recall.R: ", nrow(missing_conversions),
          " item/unit combination(s) missing a conversion factor (consumed items only).")
  print(missing_conversions %>% dplyr::count(itemcode, unit, sort = TRUE))
}

# Save diagnostic for QA review
readr::write_csv(
  missing_conversions,
  here::here("data", "processed", "01", "clean", "recall_missing_conversions.csv")
)

# =============================================================================
# OUTPUT
# =============================================================================

saveRDS(recall_kg, here::here("data", "processed", "01", "clean", "recall.rds"), compress = TRUE)

message("clean/recall.R: recall data cleaned and saved.")
