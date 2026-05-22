# =============================================================================
# clean/destinations.R
# PURPOSE: Clean crop and tree product disposition survey sections
# INPUT:   raw$destinations from 01_load_raw.R
#          clean/pc.rds, clean/pt.rds (from clean/crops.R)
# OUTPUT:  data/processed/01/clean/crop_disp.rds
#          data/processed/01/clean/tree_disp.rds
# SECTION: ag_sec_5a/5b (crop disposition), ag_sec_7a/7b (tree disposition)
# NOTE:    Clean stage only. Standardise, rename, and flag issues.
#          Gateway zeros, household repairs, merge-based diagnostics,
#          exclusion thresholds, and RPR allocation all belong in
#          impute/destinations.R.
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "01", "clean"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# SECTION 1: CROP DISPOSITION (ag_sec_5a / ag_sec_5b)
# =============================================================================

ag_sec_5a <- raw$destinations$ag_sec_5a
ag_sec_5b <- raw$destinations$ag_sec_5b

long  <- prep(ag_sec_5a, season = "long")
short <- ag_sec_5b %>%
  prep("short") %>%
  strip_colnames("5b", "5a")

labs <- prep_labs(short)
disp <- long %>% bind_dt(short)

setnames(disp, "zaocode", "cropid")
disp <- disp %>% clean_names(list = crops_list, "cropid")
label(disp) <- as.list(labs[match(names(disp), names(labs))])

crop_disp <- upData(
  disp,
  rename = .q(
    ag5a_01  = sale,
    ag5a_02  = sold_raw,
    ag5a_03  = value_sale,
    ag5a_04  = b1,
    ag5a_05  = soldb1_raw,
    ag5a_06  = value_b1,
    ag5a_08  = n_int1,
    ag5a_11  = b2,
    ag5a_12  = soldb2_raw,
    ag5a_13  = value_b2,
    ag5a_15  = n_int2,
    ag5a_23  = storage,
    ag5a_24  = stored_raw,
    ag5a_28  = storage_purpose,
    ag5a_29  = lost,
    ag5a_30  = loss_cause,
    ag5a_31  = losses_pct_raw,
    ag5a_32  = value_losses,
    ag5a_32a = consumed_raw,
    ag5a_32b = seed_raw,
    ag5a_32c = payment_raw,
    ag5a_32d = gifts_raw,
    ag5a_32e = feed_raw,
    ag5a_33  = residue_use,
    ag5a_34  = residue_raw,
    ag5a_35  = value_residue
  ),
  labels = .q(
    sale           = "Item was sold",
    sold_raw       = "Quantity sold, as reported",
    soldb1_raw     = "Quantity sold to main buyer, as reported",
    soldb2_raw     = "Quantity sold to second buyer, as reported",
    storage        = "Item is being stored",
    stored_raw     = "Quantity in storage, as reported",
    losses_pct_raw = "Post-harvest loss percentage, as reported",
    consumed_raw   = "Quantity consumed, as reported",
    seed_raw       = "Quantity kept for seed, as reported",
    payment_raw    = "Quantity given as payment, as reported",
    gifts_raw      = "Quantity given as gifts, as reported",
    feed_raw       = "Quantity used as animal feed, as reported",
    residue_raw    = "Quantity of residue sold, as reported"
  ),
  units = .q(
    sold_raw       = kg, value_sale    = `T shilling`,
    soldb1_raw     = kg, value_b1      = `T shilling`,
    soldb2_raw     = kg, value_b2      = `T shilling`,
    stored_raw     = kg, losses_pct_raw = percentage,
    consumed_raw   = kg, seed_raw      = kg,
    payment_raw    = kg, gifts_raw     = kg,
    feed_raw       = kg, residue_raw   = kg,
    value_residue  = `T shilling`
  )
)

crop_disp[, flag_sale_gate_no := fifelse(sale == "yes", 1L, 0L)]
crop_disp[, flag_storage_gate_no := fifelse(storage == "yes", 1L, 0L)]
crop_disp[, flag_loss_gate_yes := fifelse(lost == "yes", 1L, 0L)]

crop_disp[, flag_true_na_sold := fifelse(sale == "yes" & is.na(sold_raw), 1L, 0L)]
crop_disp[, flag_true_na_stored := fifelse(storage == "yes" & is.na(stored_raw), 1L, 0L)]
crop_disp[, flag_true_na_losses := fifelse(lost == "yes" & is.na(losses_pct_raw), 1L, 0L)]
crop_disp[, flag_consumed_missing := fifelse(is.na(consumed_raw), 1L, 0L)]
crop_disp[, flag_feed_missing := fifelse(is.na(feed_raw), 1L, 0L)]
crop_disp[, flag_seed_missing := fifelse(is.na(seed_raw), 1L, 0L)]
crop_disp[, flag_manual_hh_fix_needed := fifelse(y4_hhid == "8659-001" & cropid == "maize", 1L, 0L)]

message("flag_sale_gate_no: ", crop_disp[flag_sale_gate_no == 1L, .N],
        " rows where sale gateway is yes")
message("flag_storage_gate_no: ", crop_disp[flag_storage_gate_no == 1L, .N],
        " rows where storage gateway is yes")
message("flag_loss_gate_yes: ", crop_disp[flag_loss_gate_yes == 1L, .N],
        " rows where loss gateway is yes")
message("flag_true_na_sold: ", crop_disp[flag_true_na_sold == 1L, .N],
        " rows where sale is yes but sold_raw is missing")
message("flag_true_na_stored: ", crop_disp[flag_true_na_stored == 1L, .N],
        " rows where storage is yes but stored_raw is missing")
message("flag_true_na_losses: ", crop_disp[flag_true_na_losses == 1L, .N],
        " rows where loss is yes but losses_pct_raw is missing")
message("flag_consumed_missing: ", crop_disp[flag_consumed_missing == 1L, .N],
        " rows where consumed_raw is missing")
message("flag_feed_missing: ", crop_disp[flag_feed_missing == 1L, .N],
        " rows where feed_raw is missing")
message("flag_seed_missing: ", crop_disp[flag_seed_missing == 1L, .N],
        " rows where seed_raw is missing")
message("flag_manual_hh_fix_needed: ", crop_disp[flag_manual_hh_fix_needed == 1L, .N],
        " rows where maize consumption needs household-specific repair")

saveRDS(crop_disp, here::here("data", "processed", "01", "clean", "crop_disp.rds"), compress = TRUE)

flag_cols <- names(crop_disp)[grepl("^flag_", names(crop_disp))]
flag_summary <- data.table(
  flag = flag_cols,
  n = vapply(flag_cols, function(col) crop_disp[get(col) == 1L, .N], integer(1))
)[order(-n)]

message("----- Flag summary: crop_disp -----")
print(flag_summary)

readr::write_csv(
  as.data.frame(flag_summary),
  here::here("data", "processed", "01", "clean", "crop_disp_flag_summary.csv")
)

# =============================================================================
# SECTION 2: TREE DISPOSITION (ag_sec_7a / ag_sec_7b)
# =============================================================================

ag_sec_7a <- raw$destinations$ag_sec_7a
ag_sec_7b <- raw$destinations$ag_sec_7b

fruit <- prep(ag_sec_7a, season = "fruit")
perm  <- ag_sec_7b %>%
  prep("permanent") %>%
  strip_colnames("7b", "7a")

labs <- prep_labs(perm)
disp <- fruit %>% bind_dt(perm)

setnames(disp, "zaocode", "cropid")
disp <- disp %>% clean_names(list = crops_list, "cropid")
label(disp) <- as.list(labs[match(names(disp), names(labs))])

tree_disp <- upData(
  disp,
  rename = .q(
    ag7a_02 = sale,
    ag7a_03 = sold_raw,
    ag7a_04 = value_sale,
    ag7a_07_1 = b1,
    ag7a_07_2 = b2,
    ag7a_08 = storage,
    ag7a_09 = stored_raw,
    ag7a_13 = lost,
    ag7a_14 = loss_cause,
    ag7a_15 = losses_pct_raw,
    ag7a_16 = value_losses,
    ag7a_17 = consumed_raw,
    ag7a_18 = seed_raw,
    ag7a_19 = payment_raw,
    ag7a_20 = gifts_raw,
    ag7a_21 = feed_raw
  ),
  labels = .q(
    sale           = "Item was sold",
    sold_raw       = "Quantity sold, as reported",
    storage        = "Item is being stored",
    stored_raw     = "Quantity in storage, as reported",
    losses_pct_raw = "Post-harvest loss percentage, as reported",
    consumed_raw   = "Quantity consumed, as reported",
    seed_raw       = "Quantity kept for seed, as reported",
    payment_raw    = "Quantity given as payment, as reported",
    gifts_raw      = "Quantity given as gifts, as reported",
    feed_raw       = "Quantity used as animal feed, as reported"
  ),
  units = .q(
    sold_raw       = kg, value_sale = `T Shilling`,
    stored_raw     = kg, losses_pct_raw = percentage,
    consumed_raw   = kg, seed_raw = kg,
    payment_raw    = kg, gifts_raw = kg,
    feed_raw       = kg
  )
)

tree_disp[, flag_sale_gate_no := fifelse(sale == "no", 1L, 0L)]
tree_disp[, flag_storage_gate_no := fifelse(storage == "no", 1L, 0L)]
tree_disp[, flag_loss_gate_no := fifelse(lost == "no", 1L, 0L)]
tree_disp[, flag_true_na_sold := fifelse(sale == "yes" & is.na(sold_raw), 1L, 0L)]
tree_disp[, flag_true_na_stored := fifelse(storage == "yes" & is.na(stored_raw), 1L, 0L)]
tree_disp[, flag_true_na_losses := fifelse(lost == "yes" & is.na(losses_pct_raw), 1L, 0L)]
tree_disp[, flag_consumed_missing := fifelse(is.na(consumed_raw), 1L, 0L)]

for (nm in grep("^flag_", names(tree_disp), value = TRUE)) {
  message(nm, ": ", tree_disp[get(nm) == 1L, .N], " rows")
}

saveRDS(tree_disp, here::here("data", "processed", "01", "clean", "tree_disp.rds"), compress = TRUE)

flag_cols <- names(tree_disp)[grepl("^flag_", names(tree_disp))]
flag_summary <- data.table(
  flag = flag_cols,
  n = vapply(flag_cols, function(col) tree_disp[get(col) == 1L, .N], integer(1))
)[order(-n)]

message("----- Flag summary: tree_disp -----")
print(flag_summary)

readr::write_csv(
  as.data.frame(flag_summary),
  here::here("data", "processed", "01", "clean", "tree_disp_flag_summary.csv")
)

message("clean/destinations.R: crop and tree disposition outputs saved.")