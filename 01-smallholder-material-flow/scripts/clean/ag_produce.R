# =============================================================================
# clean/ag_produce.R
# PURPOSE: Clean agricultural produce / processed products survey section
# INPUT:   raw$ag_produce from 01_load_raw.R
# OUTPUT:  data/processed/clean/ag_produce.rds
#          data/processed/clean/mass_agprod_long.rds
#          data/processed/clean/mass_agprod.rds
# SECTION: ag_sec_10 — processed agricultural products and by-products
# =============================================================================

library(here)
library(tidyverse)
library(data.table)

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "clean"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# SECTION 1: LOAD AND RENAME
# ag_sec_10: volumes of processed products, by-products, and sales
# =============================================================================

ag_sec_10  <- raw$ag_produce$ag_sec_10
ag_produce <- ag_sec_10 %>% clean_up()

ag_produce <- upData(ag_produce,
  rename = .q(
    zaocode    = cropid,
    ag10_02_3  = type,
    ag10_03    = product,
    ag10_04_1  = quant,
    ag10_04_2  = unit,
    ag10_05    = input,
    ag10_06    = sales,
    ag10_07_1  = sold,
    ag10_07_2  = unit_s,
    ag10_08    = input_s,
    ag10_12_1  = buyer1,
    ag10_12_2  = buyer2
  ),
  labels = .q(
    input   = "Input quantity before processing",
    product = "Name final product",
    quant   = "Quantity by/product",
    unit    = "Unit by/product",
    sales   = "Sales conducted",
    sold    = "Quantity sold",
    unit_s  = "Unit of sales",
    input_s = "Input for sales",
    buyer1  = "Primary buyer",
    buyer2  = "Second largest buyer"
  ),
  # Replace NA with structural 0 where no sales occurred
  sold = ifelse(sales == "no", 0, sold)
)

saveRDS(ag_produce, here::here("data", "processed", "clean", "ag_produce.rds"),
        compress = TRUE)

# =============================================================================
# SECTION 2: UNIT CONVERSION — volumes to kg
# Conversion from litre to kg using product-specific densities
# Source: https://www.aqua-calc.com/calculate/food-volume-to-weight
# =============================================================================

# Items requiring conversion (not already in kg)
items <- ag_produce %>%
  select(cropid, product, unit) %>%
  unique() %>%
  filter(!is.na(cropid)) %>%
  filter(unit != "kg")

items <- clear.labels(items)

# 🚩 FLAG ASSUMPTION: All conversion factors below are density estimates from
# external literature, NOT codebook-specified. Several are NA (no reliable
# source found). Rows with NA conversion will propagate NA to produced_kg.
# Decision required before stage 3: accept NA or source additional factors.
ap_conv <- data.frame(
  cropid = c("maize", "sunflower", "cassava", "pineapple", "palm oil",
             "maize", "paddy", "paddy", "paddy", "sorghum",
             "palm oil", "palm oil", "palm oil", "sunflower", "cocoa",
             "cocoa", "sunflower", "groundnut", "palm oil", "avocado",
             "banana", "palm oil", "banana", "sunflower", "bulrush millet",
             "palm oil", "passion fruit", "sesame", "cassava"),
  product = c("flour", "palm oil", "flour", "juice", "palm oil",
              "maize bran", "flour", "rice cover", "seed", "flour",
              "other (specify)", "flour", "wet husk (wheat barley)", "wet husk (wheat barley)", "other (specify)",
              "palm oil", "juice", "palm oil", "pulp", "palm oil",
              "juice", "rubber", "other (specify)", "flour", "thread",
              "seed", "juice", "palm oil", "outer cover"),
  # Litre-to-kg conversion factors (product as starting point)
  # Sources inline; NA = no reliable source found
  conv = c(0.49, 0.92, 0.59, 1.05, 0.92,   # maize flour 0.49; sunflower oil 0.92; cassava flour 0.59; pineapple juice 1.05; palm oil 0.92
           0.3, 0.67, 0.1, 0.72, 0.51,      # maize bran 0.3; rice flour 0.67; rice cover/husk 0.1; paddy seed 0.72; sorghum flour 0.51
           1, NA, NA, NA, NA,               # palm oil 'other' assumed 1; flour/wet husk NA
           0.92, NA, 0.95, NA, 0.95,        # cocoa palm oil 0.92; sunflower juice NA; groundnut oil 0.95; palm oil pulp NA; avocado oil 0.95
           NA, NA, NA, 0.27, NA,            # banana juice NA; palm oil rubber NA; banana other NA; sunflower flour 0.27; bulrush millet thread NA
           NA, 1.04, 0.95, NA),             # palm oil seed NA; passion fruit juice 1.04; sesame oil 0.95; cassava outer cover NA
  unit = "litre",
  stringsAsFactors = FALSE
)
setDT(ap_conv)

# Diagnostic: items still needing a conversion factor
# NOTE: 'items_check' is for QA only — not used in pipeline output
items_check <- items %>%
  left_join(select(ap_conv, cropid, product, conv), by = c("cropid", "product"))

# Apply conversion (product quantities)
ap_convert <- ap_conv[ag_produce, on = c("cropid", "product", "unit")]
ap_convert[, produced  := ifelse(unit == "kg", quant, quant * conv)]
ap_convert[, input_new := ifelse(unit == "kg", input, input * conv)]
ap_convert[, `:=` (conv = NULL, unit = NULL)]

# Apply conversion (sales quantities)
ap_convert <- ap_conv[ap_convert, on = c("cropid", "product", "unit" = "unit_s")]
ap_convert[, `:=` (
  sold_new    = ifelse(unit == "kg", sold, sold * conv),
  input_s_new = ifelse(unit == "kg", input_s, input_s * conv)
)]
ap_convert[, `:=` (conv = NULL, unit = NULL)]

# =============================================================================
# SECTION 3: PRODUCT/BY-PRODUCT RECONCILIATION
# Determine which inputs belong to which products when multiple
# products and by-products are produced from the same raw input
# =============================================================================

input <- ap_convert %>%
  mutate(
    prod    = ifelse(type == "processed",   1, 0),
    byprod  = ifelse(type == "by-product",  1, 0),
    sale    = ifelse(sales == "yes",        1, 0),
    remain  = input - quant,
    consumed = quant - sold
  ) %>%
  select(y4_hhid, cropid, type, product, prod, byprod, quant, input, input_s, sold, sale, consumed) %>%
  filter(!is.na(cropid))

# Rename products for consistency
inputlong <- input %>%
  mutate(
    product = ifelse(product %in% c("other (specify)", "no waste"),  "other",     product),
    product = ifelse(product == "maize bran",                        "bran",      product),
    product = ifelse(product %in% c("outer cover", "rice cover"),    "cover",     product),
    product = ifelse(product == "palm oil",                          "oil",       product),
    product = ifelse(product == "wet husk (wheat barley)",           "wet husk",  product),
    item    = paste(cropid, product, sep = " "),
    input_s = ifelse(sold == 0, 0, input_s)
  ) %>%
  select(y4_hhid, cropid, product, item, produced = quant, sold, consumed)

saveRDS(inputlong,
        here::here("data", "processed", "clean", "mass_agprod_long.rds"),
        compress = TRUE)

# Collapse to household-crop level to assign inputs across products/by-products
input_crop <- input[, lapply(.SD, sm), .SDcols = is.numeric, by = .(y4_hhid, cropid)]

input_stats <- input_crop %>%
  mutate(
    input_s  = ifelse(sale == 2, input_s / 2, input_s),  # only one sales entry, halve
    diff     = input - quant,
    frac     = quant / input,

    # Input allocation rules — certainty decreasing down the list:
    # 🚩 FLAG ASSUMPTION: Input allocation rules use product counts and ratios.
    # Logic is heuristic: "if input / quantity == 2, split equally".
    # These rules are not codebook-derived. Document and review before stage 3.
    new_input = ifelse(prod == 1 & byprod == 0, input, NA),                            # single product
    new_input = ifelse(prod == 0 & byprod == 1, input, new_input),                     # single by-product
    new_input = ifelse(prod == 1 & byprod == 1 & input / quant == 2, input / 2, new_input),  # product + by-product equal split
    new_input = ifelse(prod == 2 & byprod == 0 & input / quant == 2, input / 2, new_input),  # two products equal split
    new_input = ifelse(prod == 3 & byprod == 0, quant, new_input),                     # three products, input = total quantity
    new_input = ifelse(prod == 2 & byprod == 1 & input / quant == 2, input / 2, new_input),
    new_input = ifelse(is.na(new_input) & quant == input, input, new_input)             # everything adds up
  )

input_stats2 <- input_stats %>%
  mutate(
    # 🚩 FLAG ASSUMPTION: Household 3208-001 input divided by 2 — appears to be
    # double-counted in raw data. Manual fix verified against raw data.
    # Flag for re-review if raw data changes.
    new_input = ifelse(y4_hhid == "3208-001", input / 2, new_input),

    # Remaining uncertain cases: progressively more uncertain allocation rules
    new_input = ifelse(is.na(new_input) & prod == 1 & byprod == 1 & quant * 2 < input,
                       input / 2, new_input),
    new_input = ifelse(is.na(new_input) & prod == 2 & byprod == 0 & quant < input,
                       input, new_input),
    new_input = ifelse(is.na(new_input) & prod == 2 & byprod == 1,
                       input * frac, new_input),
    new_input = ifelse(is.na(new_input) & input * frac == quant,
                       input * frac, new_input)
  )

input_stats <- input_stats2 %>%
  mutate(
    # 🚩 FLAG ASSUMPTION: Remaining 1 unresolved input — assigned full input as fallback.
    # Profile this row in 05_exclusions_audit.R before stage 3.
    new_input = ifelse(is.na(new_input), input, new_input)
  )

inputs_final <- input_stats %>%
  mutate(
    input_cons = new_input - input_s,
    consumed   = quant - sold
  ) %>%
  select(y4_hhid, cropid, prod, byprod,
         produced = quant, input = new_input, input_sales = input_s,
         sold, input_cons, consumed) %>%
  mutate(uncertain = input - produced)  # residual waste / unaccounted

saveRDS(inputs_final,
        here::here("data", "processed", "clean", "mass_agprod.rds"),
        compress = TRUE)

message("clean/ag_produce.R: ag produce outputs saved.")
