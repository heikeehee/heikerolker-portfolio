# =============================================================================
# impute/ag_produce.R
# PURPOSE: Convert processed-product units to kg and reconcile processing flows
# INPUT:   data/processed/01/clean/ag_produce.rds
# OUTPUT:  data/processed/01/impute/ag_produce_imputed.rds
#          data/processed/01/impute/mass_agprod_long.rds
#          data/processed/01/impute/mass_agprod.rds
#          data/processed/01/impute/ag_produce_flag_summary.csv
#          data/processed/01/impute/mass_agprod_flag_summary.csv
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "01", "impute"), showWarnings = FALSE, recursive = TRUE)

ag_produce <- readRDS(here::here("data", "processed", "01", "clean", "ag_produce.rds"))

# =============================================================================
# TIER 1: UNIT CONVERSION TABLES
# =============================================================================

ap_conv_prod <- data.table(
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
  conv = c(0.49, 0.92, 0.59, 1.05, 0.92,
           0.3, 0.67, 0.1, 0.72, 0.51,
           1, NA, NA, NA, NA,
           0.92, NA, 0.95, NA, 0.95,
           NA, NA, NA, 0.27, NA,
           NA, 1.04, 0.95, NA),
  unit_prod = "litre"
)

ap_conv_sale <- copy(ap_conv_prod)
setnames(ap_conv_sale, "unit_prod", "unit_sale")

# =============================================================================
# TIER 2: CONVERSION AND RECONCILIATION
# =============================================================================

ag_produce[, `:=`(
  unit_prod = unit_raw,
  unit_sale = unit_s_raw
)]

ap_convert <- ap_conv_prod[ag_produce, on = .(cropid, product, unit_prod)]

ap_convert[, quant_kg := fifelse(unit_prod == "kg", as.numeric(quant_raw), as.numeric(quant_raw) * conv)]
ap_convert[, input_kg := fifelse(unit_prod == "kg", as.numeric(input_raw), as.numeric(input_raw) * conv)]
ap_convert[, flag_product_conversion_missing := fifelse(unit_prod != "kg" & is.na(conv), 1L, 0L)]
ap_convert[, flag_product_conversion_applied := fifelse(unit_prod != "kg" & !is.na(conv), 1L, 0L)]

ap_convert <- ap_conv_sale[ap_convert, on = .(cropid, product, unit_sale)]

ap_convert[, sold_kg := fifelse(unit_sale == "kg", as.numeric(sold_raw), as.numeric(sold_raw) * conv)]
ap_convert[, input_s_kg := fifelse(unit_sale == "kg", as.numeric(input_s_raw), as.numeric(input_s_raw) * conv)]
ap_convert[, flag_sales_conversion_missing := fifelse(unit_sale != "kg" & !is.na(unit_sale) & is.na(conv), 1L, 0L)]
ap_convert[, flag_sales_conversion_applied := fifelse(unit_sale != "kg" & !is.na(conv), 1L, 0L)]

ap_convert[, c("unit_prod", "unit_sale") := NULL]

ap_convert[, sold_kg := fifelse(sales == "no", 0, sold_kg)]
ap_convert[, input_s_kg := fifelse(sales == "no", 0, input_s_kg)]

# Processing-flow reconciliation
input <- ap_convert %>%
  mutate(
    prod = ifelse(type == "processed", 1, 0),
    byprod = ifelse(type == "by-product", 1, 0),
    sale = ifelse(sales == "yes", 1, 0),
    consumed = quant_kg - sold_kg
  ) %>%
  select(y4_hhid, cropid, type, product, prod, byprod,
         quant_kg, input_kg, input_s_kg, sold_kg, sale, consumed) %>%
  filter(!is.na(cropid))

inputlong <- input %>%
  mutate(
    product = ifelse(product %in% c("other (specify)", "no waste"), "other", product),
    product = ifelse(product == "maize bran", "bran", product),
    product = ifelse(product %in% c("outer cover", "rice cover"), "cover", product),
    product = ifelse(product == "palm oil", "oil", product),
    product = ifelse(product == "wet husk (wheat barley)", "wet husk", product),
    item = paste(cropid, product, sep = " "),
    input_s_kg = ifelse(sold_kg == 0, 0, input_s_kg)
  ) %>%
  select(y4_hhid, cropid, product, item, produced = quant_kg, sold = sold_kg, consumed)

saveRDS(inputlong, here::here("data", "processed", "01", "impute", "mass_agprod_long.rds"), compress = TRUE)

input_crop <- as.data.table(input)[, lapply(.SD, sm), .SDcols = is.numeric, by = .(y4_hhid, cropid)]

input_stats <- input_crop %>%
  mutate(
    input_s_kg = ifelse(sale == 2, input_s_kg / 2, input_s_kg),
    diff = input_kg - quant_kg,
    frac = quant_kg / input_kg,
    new_input = ifelse(prod == 1 & byprod == 0, input_kg, NA),
    new_input = ifelse(prod == 0 & byprod == 1, input_kg, new_input),
    new_input = ifelse(prod == 1 & byprod == 1 & input_kg / quant_kg == 2, input_kg / 2, new_input),
    new_input = ifelse(prod == 2 & byprod == 0 & input_kg / quant_kg == 2, input_kg / 2, new_input),
    new_input = ifelse(prod == 3 & byprod == 0, quant_kg, new_input),
    new_input = ifelse(prod == 2 & byprod == 1 & input_kg / quant_kg == 2, input_kg / 2, new_input),
    new_input = ifelse(is.na(new_input) & quant_kg == input_kg, input_kg, new_input)
  )

input_stats2 <- input_stats %>%
  mutate(
    new_input = ifelse(y4_hhid == "3208-001", input_kg / 2, new_input),
    flag_manual_input_split = ifelse(y4_hhid == "3208-001", 1L, 0L),
    new_input = ifelse(is.na(new_input) & prod == 1 & byprod == 1 & quant_kg * 2 < input_kg, input_kg / 2, new_input),
    new_input = ifelse(is.na(new_input) & prod == 2 & byprod == 0 & quant_kg < input_kg, input_kg, new_input),
    new_input = ifelse(is.na(new_input) & prod == 2 & byprod == 1, input_kg * frac, new_input),
    new_input = ifelse(is.na(new_input) & input_kg * frac == quant_kg, input_kg * frac, new_input)
  )

input_stats3 <- input_stats2 %>%
  mutate(
    flag_input_fallback_full = ifelse(is.na(new_input), 1L, 0L),
    new_input = ifelse(is.na(new_input), input_kg, new_input)
  )

inputs_final <- input_stats3 %>%
  mutate(
    input_cons = new_input - input_s_kg,
    consumed = quant_kg - sold_kg,
    uncertain = new_input - quant_kg,
    flag_negative_consumed = ifelse(consumed < 0, 1L, 0L),
    flag_negative_uncertain = ifelse(uncertain < 0, 1L, 0L)
  ) %>%
  select(y4_hhid, cropid, prod, byprod,
         produced = quant_kg, input = new_input, input_sales = input_s_kg,
         sold = sold_kg, input_cons, consumed, uncertain,
         flag_manual_input_split, flag_input_fallback_full,
         flag_negative_consumed, flag_negative_uncertain)

saveRDS(ap_convert, here::here("data", "processed", "01", "impute", "ag_produce_imputed.rds"), compress = TRUE)
saveRDS(inputs_final, here::here("data", "processed", "01", "impute", "mass_agprod.rds"), compress = TRUE)

message("flag_product_conversion_missing: ", ap_convert[flag_product_conversion_missing == 1L, .N])
message("flag_product_conversion_applied: ", ap_convert[flag_product_conversion_applied == 1L, .N])
message("flag_sales_conversion_missing: ", ap_convert[flag_sales_conversion_missing == 1L, .N])
message("flag_sales_conversion_applied: ", ap_convert[flag_sales_conversion_applied == 1L, .N])
message("flag_manual_input_split: ", inputs_final[flag_manual_input_split == 1L, .N])
message("flag_input_fallback_full: ", inputs_final[flag_input_fallback_full == 1L, .N])
message("flag_negative_consumed: ", inputs_final[flag_negative_consumed == 1L, .N])
message("flag_negative_uncertain: ", inputs_final[flag_negative_uncertain == 1L, .N])

flag_summary <- function(dt) {
  fc <- names(dt)[grepl("^flag_", names(dt))]
  data.table(flag = fc, n = vapply(fc, function(col) dt[get(col) == 1L, .N], integer(1)))[order(-n)]
}

readr::write_csv(as.data.frame(flag_summary(ap_convert)),
                 here::here("data", "processed", "01", "impute", "ag_produce_flag_summary.csv"))
readr::write_csv(as.data.frame(flag_summary(as.data.table(inputs_final))),
                 here::here("data", "processed", "01", "impute", "mass_agprod_flag_summary.csv"))

message("impute/ag_produce.R: ag produce outputs saved.")