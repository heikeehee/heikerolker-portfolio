# =============================================================================
# clean/recall.R
# PURPOSE: Clean household 7-day food consumption recall survey section
# INPUT:   raw$recall from 01_load_raw.R
# OUTPUT:  data/processed/clean/recall.rds
# SECTION: hh_sec_j1 — household Section J1 (food consumption recall)
# =============================================================================

library(here)
library(tidyverse)

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "clean"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# CONSTANTS
# =============================================================================

KG_PER_GRAM <- 0.001

# =============================================================================
# CONVERSION REFERENCE TABLE
# Maps (itemcode, unit) → conversion factor to kg
# Sources: product-specific densities from literature (see inline comments)
# =============================================================================

# 🚩 FLAG ASSUMPTION: All conversion factors below are assumed from literature or
# standard density references, NOT from the LSMS codebook directly. Review each
# factor against the codebook or a verified reference before stage 3.
food_conv <- tibble::tribble(
  ~unit,         ~itemcode,                                                     ~conv,
  "litre",       "fresh milk",                                                  1.08,
  "pieces",      "eggs",                                                        0.0408,
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
  "litre",       "canned, dried and wild vegetables",                           0.3
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
    dplyr::left_join(items_ref, by = c("itemcode", setNames("unit", unit_col))) %>%
    dplyr::mutate(
      "{qty_col}_kg" := dplyr::case_when(
        .data[[unit_col]] == "kilograms" ~ .data[[qty_col]],
        .data[[unit_col]] == "grams"     ~ .data[[qty_col]] * KG_PER_GRAM,
        !is.na(conv)                     ~ .data[[qty_col]] * conv,
        TRUE                             ~ NA_real_
      )
    ) %>%
    dplyr::select(-conv, -all_of(unit_col))
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
  dplyr::filter(if_any(ends_with("_kg"), is.na)) %>%
  dplyr::distinct(itemcode, .keep_all = FALSE)

if (nrow(missing_conversions) > 0) {
  # 🚩 FLAG UNIT: Missing conversion factors detected — quantities will be NA_real_.
  # These item/unit combinations are not covered by food_conv. Add factors or
  # mark as unresolvable before stage 3.
  message("clean/recall.R: ", nrow(missing_conversions),
          " item/unit combination(s) missing a conversion factor.")
  print(missing_conversions %>% dplyr::count(itemcode, sort = TRUE))
}

# Save diagnostic for QA review
readr::write_csv(
  missing_conversions,
  here::here("data", "processed", "clean", "recall_missing_conversions.csv")
)

# =============================================================================
# OUTPUT
# =============================================================================

saveRDS(recall_kg, here::here("data", "processed", "clean", "recall.rds"), compress = TRUE)

message("clean/recall.R: recall data cleaned and saved.")
