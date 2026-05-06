# Convert household recall data to kilograms with standard conversions
# Portfolio-ready: explicit, auditable, reproducible

library(here)
# Load core packages and custom functions
source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

# -- 1. Setup and Constants ----------------------------------------------------
KG_PER_GRAM <- 0.001

# -- 2. Load Conversion Reference ----------------------------------------------
# Your original hard-coded table; in practice, load from CSV for version control:
food_conv <- tibble::tribble(
  ~unit,       ~itemcode,                                                          ~conv,
  "litre",     "fresh milk",                                                      1.08,
  "pieces",    "eggs",                                                            0.0408,
  "litre",     "milk products (like cream, cheese, yoghurt etc)",                 1.01,
  "litre",     "cooking oil",                                                     0.9,
  "litre",     "bottled/canned soft drinks (soda, juice, water)",                 1,
  "litre",     "bottled beer",                                                    1,
  "litre",     "local brews",                                                     1,
  "litre",     "honey, syrups, jams, marmalade, jellies, canned fruits",          1.43,
  "litre",     "buns, cakes and biscuits",                                        0.02,
  "pieces",    "bread",                                                           0.5,
  "pieces",    "coconuts (mature/immature)",                                      0.8,
  "pieces",    "sweets",                                                          0.05,
  "millilitre","cooking oil",                                                     0.001,
  "millilitre","fresh milk",                                                      0.001,
  "millilitre","milk products (like cream, cheese, yoghurt etc)",                 0.001,
  "millilitre","bottled/canned soft drinks (soda, juice, water)",                 0.001,
  "millilitre","honey, syrups, jams, marmalade, jellies, canned fruits",          0.001,
  "millilitre","wine and spirits",                                                0.001,
  "millilitre","bottled beer",                                                    0.001,
  "millilitre","local brews",                                                     0.001,
  "millilitre","prepared tea, coffee",                                            0.001,
  "millilitre","peas, beans, lentils and other pulses",                           0.001,
  "pieces",    "bottled/canned soft drinks (soda, juice, water)",                 0.355,
  "litre",     "butter, margarine, ghee and other fat products",                  0.959,
  "litre",     "sweet potatoes",                                                  0.66,
  "litre",     "canned, dried and wild vegetables",                               0.3
)
# Append explicit conversions for all items for "kilograms" (1) and "grams" (0.001)
food_conv <- dplyr::bind_rows(
  food_conv,
  tibble::tibble(
    unit = rep("kilograms", times = length(unique(food_conv$itemcode))),
    itemcode = unique(food_conv$itemcode),
    conv = 1
  ),
  tibble::tibble(
    unit = rep("grams", times = length(unique(food_conv$itemcode))),
    itemcode = unique(food_conv$itemcode),
    conv = 0.001
  )
) %>%
  dplyr::distinct()

# Add kg/g as identity conversions *for every item*
unique_items <- unique(food_conv$itemcode)
food_conv <- dplyr::bind_rows(
  food_conv,
  tibble::tibble(
    unit = rep("kilograms", times = length(unique_items)),
    itemcode = unique_items,
    conv = 1
  ),
  tibble::tibble(
    unit = rep("grams", times = length(unique_items)),
    itemcode = unique_items,
    conv = KG_PER_GRAM
  )
) %>% dplyr::distinct()

# --- 3. Load Recall Data ------------------------------------------------------
recall <- haven::read_dta(
  here::here("data", "raw", "lsms", "hh_sec_j1.dta")
)

# For pipeline reproducibility—always label and glimpse at load
if (interactive()) {
  lapply(recall, attr, "label")
  dplyr::glimpse(recall)
}

# --- 4. Clean and Rename Columns ----------------------------------------------
recall <- recall %>%
  clean_up() %>% # your assumed cleaning function
  dplyr::rename(
    consumed     = hh_j01,
    quantity     = hh_j02_2,   unit   = hh_j02_1,
    purchases    = hh_j03_2,   u_bought   = hh_j03_1,
    value        = hh_j04,     source      = hh_j04_1,
    production   = hh_j05_2,   u_produced  = hh_j05_1,
    gifts        = hh_j06_2,   u_gifts     = hh_j06_1
  ) %>%
  dplyr::mutate(across(c(unit, u_bought, u_produced, u_gifts), as.character))

# --- 5. Conversion Helper Function --------------------------------------------
convert_to_kg <- function(df, qty_col, unit_col, items_ref) {
  df %>%
    dplyr::left_join(items_ref, by = c("itemcode", setNames("unit", unit_col))) %>%
    dplyr::mutate(
      "{qty_col}_kg" := dplyr::case_when(
        .data[[unit_col]] == "kilograms" ~ .data[[qty_col]],
        .data[[unit_col]] == "grams" ~ .data[[qty_col]] * KG_PER_GRAM,
        !is.na(conv) ~ .data[[qty_col]] * conv,
        TRUE ~ NA_real_
      )
    ) %>%
    dplyr::select(-conv, -all_of(unit_col))
}

# --- 6. Convert all Quantity Columns to kg ------------------------------------
# Assume itemcode is present (if not, join by relevant field first)
recall_kg <- recall %>%
  convert_to_kg("quantity",   "unit",       food_conv) %>%
  convert_to_kg("purchases",  "u_bought",   food_conv) %>%
  convert_to_kg("production", "u_produced", food_conv) %>%
  convert_to_kg("gifts",      "u_gifts",    food_conv)

# --- 7. DIAGNOSTIC: Report Unmatched itemcode/unit ----------------------------
missing_conversions <- recall_kg %>%
  dplyr::filter(if_any(ends_with("_kg"), is.na)) %>%
  dplyr::distinct(itemcode, .keep_all = FALSE)

if (nrow(missing_conversions) > 0) {
  message(nrow(missing_conversions), " item/unit conversion(s) missing.")
  print(missing_conversions %>% dplyr::count(itemcode, sort = TRUE))
}

# Optional: Save diagnostic for QA review
readr::write_csv(missing_conversions, here::here("data", "processed", "02", "missing_conversions.csv"))

# --- 8. Save output -----------------------------------------------------------
saveRDS(recall_kg, here::here("data", "processed", "02", "recall_kg.RDS"), compress = TRUE)