# =============================================================================
# clean/recall.R
# PURPOSE: Clean household 7-day food consumption recall survey section
# INPUT:   raw$recall from 01_load_raw.R
# OUTPUT:  data/processed/01/clean/recall.rds
#          data/processed/01/clean/recall_missing_conversions.csv
# SECTION: hh_sec_j1 — household Section J1 (food consumption recall)
# NOTE:    Cleaning only. Standardise, convert where supported, and flag gaps.
#          Do not invent new conversion factors here.
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

# ASSUMPTION A1: All conversion factors below are assumed from literature or
# standard density references, not from the LSMS codebook directly.
# REVIEW: several factors are heuristic or context-specific and need explicit source notes.
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
  "litre",       "canned, dried and wild vegetables",                           0.3,
  "pieces",      "buns, cakes and biscuits",                                    0.1
)

# FLAG F1: heuristic conversion factors that need explicit source review.
flag_conv_review <- food_conv %>%
  dplyr::filter(
    (unit == "litre"  & itemcode %in% c("buns, cakes and biscuits", "sweet potatoes", "canned, dried and wild vegetables")) |
      (unit == "pieces" & itemcode %in% c("bread", "coconuts (mature/immature)", "sweets", "buns, cakes and biscuits", "bottled/canned soft drinks (soda, juice, water)"))
  )

n_flag_conv_review <- nrow(flag_conv_review)
message("flag_conv_review: ", n_flag_conv_review,
        " conversion factor rows flagged for source review before publication")

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

# FLAG F2: duplicate household-item rows in raw recall data.
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
        is.na(.data[[qty_col]])                           ~ NA_real_,
        .data[[qty_col]] == 0 & is.na(.data[[unit_col]])  ~ 0,
        .data[[unit_col]] == "kilograms"                 ~ .data[[qty_col]],
        .data[[unit_col]] == "grams"                     ~ .data[[qty_col]] * KG_PER_GRAM,
        !is.na(conv)                                      ~ .data[[qty_col]] * conv,
        TRUE                                              ~ NA_real_
      )
    ) %>%
    dplyr::select(-conv)
}

recall_kg <- recall %>%
  convert_to_kg("quantity",   "unit",       food_conv) %>%
  convert_to_kg("purchases",  "u_bought",   food_conv) %>%
  convert_to_kg("production", "u_produced", food_conv) %>%
  convert_to_kg("gifts",      "u_gifts",    food_conv)

# =============================================================================
# FLAGS: missing conversions and review conditions
# =============================================================================

# FLAG F3: consumed == yes but quantity missing.
recall_kg <- recall_kg %>%
  dplyr::mutate(
    flag_quantity_missing = dplyr::if_else(consumed == "yes" & is.na(quantity), 1L, 0L),
    flag_value_missing = dplyr::if_else(consumed == "yes" & purchases > 0 & is.na(value), 1L, 0L),
    flag_source_missing = dplyr::if_else(consumed == "yes" & purchases > 0 & is.na(source), 1L, 0L),
    flag_consumed_no_but_quantity = dplyr::if_else(consumed == "no" & coalesce(quantity, 0) > 0, 1L, 0L),
    flag_unit_missing = dplyr::if_else(consumed == "yes" & quantity > 0 & is.na(unit), 1L, 0L),
    flag_unit_production_missing = dplyr::if_else(consumed == "yes" & production > 0 & is.na(u_produced), 1L, 0L),
    flag_unit_purchases_missing = dplyr::if_else(consumed == "yes" & purchases > 0 & is.na(u_bought), 1L, 0L),
    flag_unit_gifts_missing = dplyr::if_else(consumed == "yes" & gifts > 0 & is.na(u_gifts), 1L, 0L)
  )

n_flag_quantity_missing <- sum(recall_kg$flag_quantity_missing, na.rm = TRUE)
n_flag_value_missing <- sum(recall_kg$flag_value_missing, na.rm = TRUE)
n_flag_source_missing <- sum(recall_kg$flag_source_missing, na.rm = TRUE)
n_flag_consumed_no_but_quantity <- sum(recall_kg$flag_consumed_no_but_quantity, na.rm = TRUE)
n_flag_unit_missing <- sum(recall_kg$flag_unit_missing, na.rm = TRUE)
n_flag_unit_production_missing <- sum(recall_kg$flag_unit_production_missing, na.rm = TRUE)
n_flag_unit_purchases_missing <- sum(recall_kg$flag_unit_purchases_missing, na.rm = TRUE)
n_flag_unit_gifts_missing <- sum(recall_kg$flag_unit_gifts_missing, na.rm = TRUE)



message("flag_quantity_missing: ", n_flag_quantity_missing,
        " consumed items with missing quantity")
message("flag_value_missing: ", n_flag_value_missing,
        " consumed items with acquisition amounts but missing value")
message("flag_source_missing: ", n_flag_source_missing,
        " consumed items from purchase with value present but source missing")
message("flag_consumed_no_but_quantity: ", n_flag_consumed_no_but_quantity,
        " items marked not consumed but with positive quantity")
message("flag_unit_missing: ", n_flag_unit_missing,
        " items marked consumed but unit missing")
message("flag_unit_production_missing: ", n_flag_unit_production_missing,
        " items marked consumed from production but unit missing")
message("flag_unit_purchases_missing: ", n_flag_unit_purchases_missing,
        " items marked consumed from purchases but unit missing")
message("flag_unit_gifts_missing: ", n_flag_unit_gifts_missing,
        " items marked consumed from gifts but unit missing")

# FLAG F4: genuine missing conversion factors on consumed items.
missing_conversions <- recall_kg %>%
  dplyr::filter(consumed == "yes") %>%
  dplyr::filter(
    (!is.na(quantity)   & quantity   != 0 & is.na(quantity_kg)) |
      (!is.na(purchases)  & purchases  != 0 & is.na(purchases_kg)) |
      (!is.na(production) & production != 0 & is.na(production_kg)) |
      (!is.na(gifts)      & gifts      != 0 & is.na(gifts_kg))
  ) %>%
  dplyr::distinct(itemcode, unit, .keep_all = TRUE) %>%
  dplyr::select(itemcode, unit, starts_with("u_"),
                quantity, quantity_kg,
                purchases, purchases_kg,
                production, production_kg,
                gifts, gifts_kg)

n_missing_conversions <- nrow(missing_conversions)
message("missing_conversions: ", n_missing_conversions,
        " item/unit combinations missing a conversion factor (consumed items only)")
if (n_missing_conversions > 0) {
  print(missing_conversions %>% dplyr::count(itemcode, unit, sort = TRUE))
}

# FLAG F5: total acquisition components do not reconcile with reported quantity.
recall_kg <- recall_kg %>%
  dplyr::mutate(
    acquired_kg = rowSums(dplyr::across(c(purchases_kg, production_kg, gifts_kg)), na.rm = TRUE),
    flag_quantity_component_mismatch = dplyr::if_else(
      consumed == "yes" & quantity_kg < acquired_kg,
      1L,
      0L
    )
  )

n_flag_quantity_component_mismatch <- sum(recall_kg$flag_quantity_component_mismatch, na.rm = TRUE)
message("flag_quantity_component_mismatch: ", n_flag_quantity_component_mismatch,
        " consumed items where quantity_kg does not match purchases_kg + production_kg + gifts_kg")

readr::write_csv(
  missing_conversions,
  here::here("data", "processed", "01", "clean", "recall_missing_conversions.csv")
)

# =============================================================================
# FLAG SUMMARY
# =============================================================================

flag_cols <- names(recall_kg)[grepl("^flag_", names(recall_kg))]
flag_summary <- data.table(
  flag = flag_cols,
  n = vapply(flag_cols, function(col) recall_kg[get(col) == 1L, .N], integer(1))
)[order(-n)]

message("----- Flag summary: recall -----")
print(flag_summary)

readr::write_csv(
  as.data.frame(flag_summary),
  here::here("data", "processed", "01", "clean", "recall_flag_summary.csv")
)

# =============================================================================
# OUTPUT
# =============================================================================

saveRDS(recall_kg, here::here("data", "processed", "01", "clean", "recall.rds"), compress = TRUE)
message("clean/recall.R: recall data cleaned and saved")