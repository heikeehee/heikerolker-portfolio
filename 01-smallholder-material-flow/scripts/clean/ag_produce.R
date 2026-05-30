# =============================================================================
# clean/ag_produce.R
# PURPOSE: Clean agricultural produce / processed products survey section
# INPUT:   raw$ag_produce from 01_load_raw.R
# OUTPUT:  data/processed/01/clean/ag_produce.rds
#          data/processed/01/clean/ag_produce_flag_summary.csv
# SECTION: ag_sec_10 — processed agricultural products and by-products
# NOTE:    Clean stage only. Standardise names, labels, and section-level flags.
#          Unit conversion, reconciliation, allocation rules, and extraction-rate
#          assumptions belong in impute/ag_produce.R and impute/processed_crops.R.
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "01", "clean"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# SECTION 1: LOAD AND RENAME
# =============================================================================

ag_sec_10  <- raw$ag_produce$ag_sec_10
ag_produce <- ag_sec_10 %>% clean_up()

ag_produce <- upData(
  ag_produce,
  rename = .q(
    zaocode    = cropid,
    ag10_02_3  = type,
    ag10_03    = product,
    ag10_04_1  = quant_raw,
    ag10_04_2  = unit_raw,
    ag10_05    = input_raw,
    ag10_06    = sales,
    ag10_07_1  = sold_raw,
    ag10_07_2  = unit_s_raw,
    ag10_08    = input_s_raw,
    ag10_12_1  = buyer1,
    ag10_12_2  = buyer2
  ),
  labels = .q(
    type       = "Processed product or by-product type",
    product    = "Name of final product",
    quant_raw  = "Quantity of product/by-product, as reported",
    unit_raw   = "Unit of product/by-product, as reported",
    input_raw  = "Input quantity before processing, as reported",
    sales      = "Sales conducted",
    sold_raw   = "Quantity sold, as reported",
    unit_s_raw = "Unit of sales quantity, as reported",
    input_s_raw = "Input associated with sales, as reported",
    buyer1     = "Primary buyer",
    buyer2     = "Second largest buyer"
  )
)

# Structural zero only: if no sales, sold should be zero
ag_produce[, sold_kg := fifelse(sales == "no", 0, as.numeric(sold_raw))]

# =============================================================================
# SECTION 2: CLEAN-STAGE FLAGS
# =============================================================================

ag_produce[, flag_sales_gate_yes := fifelse(sales == "yes" & !is.na(type), 1L, 0L)]

ag_produce[, flag_true_na_sold := fifelse(sales == "yes" & is.na(sold_raw), 1L, 0L)]
ag_produce[, flag_true_na_unit_s := fifelse(sales == "yes" & is.na(unit_s_raw), 1L, 0L)]
ag_produce[, flag_true_na_input_s := fifelse(sales == "yes" & is.na(input_s_raw), 1L, 0L)]

ag_produce[, flag_quant_missing := fifelse(is.na(quant_raw) & !is.na(type), 1L, 0L)]
ag_produce[, flag_input_missing := fifelse(is.na(input_raw) & !is.na(type), 1L, 0L)]
ag_produce[, flag_unit_missing := fifelse(is.na(unit_raw) & !is.na(type), 1L, 0L)]
ag_produce[, flag_no_product := fifelse(is.na(product) & !is.na(cropid), 1L, 0L)]
ag_produce[, flag_cropid_product_missing := fifelse(is.na(cropid) & !is.na(type), 1L, 0L)]

ag_produce[, flag_unit_needs_conversion := fifelse(!is.na(unit_raw) & unit_raw != "kg", 1L, 0L)]
ag_produce[, flag_sales_unit_needs_conversion := fifelse(!is.na(unit_s_raw) & unit_s_raw != "kg", 1L, 0L)]

ag_produce[, flag_product_type := fifelse(type == "processed", 1L, 0L)]
ag_produce[, flag_byproduct_type := fifelse(type == "by-product", 1L, 0L)]

ag_produce[, flag_sold_gt_quant_raw := fifelse(
  !is.na(sold_raw) & !is.na(quant_raw) & sold_raw > quant_raw,
  1L, 0L
)]

message("flag_sales_gate_yes: ", ag_produce[flag_sales_gate_yes == 1L, .N],
        " rows where sales gateway is no")
message("flag_sales_gate_yes: ", ag_produce[flag_sales_gate_yes == 1L, .N],
        " rows where sales gateway is yes")
message("flag_true_na_sold: ", ag_produce[flag_true_na_sold == 1L, .N],
        " rows where sales is yes but sold_raw is missing")
message("flag_true_na_unit_s: ", ag_produce[flag_true_na_unit_s == 1L, .N],
        " rows where sales is yes but unit_s_raw is missing")
message("flag_true_na_input_s: ", ag_produce[flag_true_na_input_s == 1L, .N],
        " rows where sales is yes but input_s_raw is missing")
message("flag_quant_missing: ", ag_produce[flag_quant_missing == 1L, .N],
        " rows where quant_raw is missing")
message("flag_input_missing: ", ag_produce[flag_input_missing == 1L, .N],
        " rows where input_raw is missing")
message("flag_unit_missing: ", ag_produce[flag_unit_missing == 1L, .N],
        " rows where unit_raw is missing")
message("flag_no_product: ", ag_produce[flag_no_product == 1L, .N],
        " rows where product is missing")
message("flag_cropid_product_missing: ", ag_produce[flag_cropid_product_missing == 1L, .N],
        " rows where cropid for product is missing")
message("flag_unit_needs_conversion: ", ag_produce[flag_unit_needs_conversion == 1L, .N],
        " rows where product quantity unit is not kg")
message("flag_sales_unit_needs_conversion: ", ag_produce[flag_sales_unit_needs_conversion == 1L, .N],
        " rows where sales quantity unit is not kg")
message("flag_product_type: ", ag_produce[flag_product_type == 1L, .N],
        " rows flagged as processed products")
message("flag_byproduct_type: ", ag_produce[flag_byproduct_type == 1L, .N],
        " rows flagged as by-products")
message("flag_sold_gt_quant_raw: ", ag_produce[flag_sold_gt_quant_raw == 1L, .N],
        " rows where sold_raw exceeds quant_raw")

saveRDS(
  ag_produce,
  here::here("data", "processed", "01", "clean", "ag_produce.rds"),
  compress = TRUE
)

flag_cols <- names(ag_produce)[grepl("^flag_", names(ag_produce))]
flag_summary <- data.table(
  flag = flag_cols,
  n = vapply(flag_cols, function(col) ag_produce[get(col) == 1L, .N], integer(1))
)[order(-n)]

message("----- Flag summary: tree_disp -----")
print(flag_summary)

readr::write_csv(
  as.data.frame(flag_summary),
  here::here("data", "processed", "01", "clean", "ag_produce_flag_summary.csv")
)

message("clean/ag_produce.R: ag produce outputs saved.")