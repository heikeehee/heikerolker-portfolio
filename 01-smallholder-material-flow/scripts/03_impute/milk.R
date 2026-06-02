# =============================================================================
# impute/milk.R
# PURPOSE: Apply repair, fallback, reconciliation, uncertainty, and feed rules
#          for milk production outputs
# INPUT:   clean/milk.rds
#          clean/feed_short.rds
# OUTPUT:  data/processed/01/impute/milk_imputed.rds
#          data/processed/01/impute/mass_milk_imputed.rds
#          data/processed/01/impute/mass_milk_final_imputed.rds
#          data/processed/01/impute/excl_milk_imputed.csv
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "01", "impute"), showWarnings = FALSE, recursive = TRUE)

milk <- readRDS(here::here("data", "processed", "01", "clean", "milk.rds"))
feed_short <- readRDS(here::here("data", "processed", "01", "clean", "feed_short.rds"))

# =============================================================================
# SECTION 1: MANUAL REPAIRS AND STANDARDISATION
# =============================================================================

milk[, av := as.numeric(av_raw)]
milk[, hi := as.numeric(hi_raw)]
milk[, lo := as.numeric(lo_raw)]
milk[, consumed := as.numeric(consumed_raw)]
milk[, sold := as.numeric(sold_raw)]
milk[, processed := as.numeric(processed_raw)]
milk[, psold := as.numeric(psold_raw)]
milk[, value := as.numeric(value_raw)]

# ASSUMPTION M1: household-specific repairs for missing average milk production
milk[y4_hhid == "1001-001" & is.na(av), av := lo]
milk[y4_hhid == "1002-001" & is.na(av), av := (lo + hi) / 2]
milk[y4_hhid == "2943-001" & is.na(av), av := consumed + sold + psold]

milk[, flag_manual_av_fix_applied := fifelse(
  y4_hhid %in% c("1001-001", "1002-001", "2943-001") & !is.na(av),
  1L, 0L
)]

# ASSUMPTION M2: average month length converted to days using 30.437
milk[, period := as.numeric(length) * 30.437]
milk[, flag_period_days_applied := fifelse(!is.na(length), 1L, 0L)]

# =============================================================================
# SECTION 2: MILK QUANTITY RECONCILIATION
# =============================================================================

# ASSUMPTION M3: if processed < psold, use psold as the effective processed quantity
milk[, processed_new := fifelse(is.na(processed), 0, processed)]
milk[!is.na(psold) & (is.na(processed_new) | processed_new < psold), processed_new := psold]
milk[, flag_processed_repaired := fifelse(
  !is.na(processed) & !is.na(psold) & processed < psold,
  1L, 0L
)]

milk[, smd1 := rowSums(.SD, na.rm = TRUE), .SDcols = c("consumed", "sold", "processed_new")]

# ASSUMPTION M4: if av is missing, use the sum of dispositions as fallback
milk[, av_with_fallback := fifelse(is.na(av), smd1, av)]
milk[, flag_av_fallback_applied := fifelse(is.na(av) & !is.na(smd1), 1L, 0L)]

milk[, simple_av := (av_with_fallback + hi + lo) / 3]
milk[, weighted_av := fifelse(is.na(av), smd1, 0.8 * av + 0.2 * smd1)]
milk[, geo_av := fifelse(is.na(av), sqrt(smd1 * smd1), sqrt(av * smd1))]

milk[, corrected_avg := fifelse(
  is.na(av_with_fallback) | is.na(lo) | is.na(hi),
  av_with_fallback,
  pmin(pmax(av_with_fallback, lo), hi)
)]

milk[, corrected_min := fifelse(is.na(lo) | is.na(corrected_avg), lo, pmin(lo, corrected_avg))]
milk[, corrected_max := fifelse(is.na(hi) | is.na(corrected_avg), hi, pmax(hi, corrected_avg))]

# ASSUMPTION M5: uncertainty approximated as range / 4
milk[, range := fifelse(is.na(corrected_max) | is.na(corrected_min), NA_real_, corrected_max - corrected_min)]
milk[, SD := fifelse(is.na(range), NA_real_, range / 4)]
milk[, flag_sd_approx_applied := fifelse(!is.na(range), 1L, 0L)]

# ASSUMPTION M6: representative production uses weighted min/avg/max blend
milk[, new_av := fifelse(
  av == smd1,
  av,
  0.2 * corrected_min + 0.6 * corrected_avg + 0.2 * corrected_max
)]
milk[, flag_new_av_imputed := fifelse(!is.na(new_av), 1L, 0L)]

# =============================================================================
# SECTION 3: EXCLUSION REVIEW
# =============================================================================

excl_milk_imputed <- milk[milked > 0, .(
  y4_hhid,
  lvstckcat,
  corrected_avg,
  corrected_min,
  corrected_max,
  new_av,
  av_with_fallback,
  SD,
  consumed,
  sold,
  processed,
  processed_new,
  psold,
  period,
  milked,
  smd1
)]

excl_milk_imputed[, excl := fcase(
  period > 310 & milked == 1, "Implausible",
  smd1 > 7 & milked == 1, "Implausible",
  new_av * 1.2 < consumed | new_av * 1.2 < sold | new_av * 1.2 < processed_new, "Data inconsistent",
  smd1 > new_av * 1.5, "Excessive milk use",
  smd1 <= new_av * 0.5, "Milk unaccounted"
)]

excl_milk_imputed[, item := paste("milk", lvstckcat, sep = " - ")]

write.csv(
  excl_milk_imputed[, .(y4_hhid, item, excl)],
  here::here("data", "processed", "01", "impute", "excl_milk_imputed.csv"),
  row.names = FALSE
)

# =============================================================================
# SECTION 4: ANNUALISED MASS MILK
# =============================================================================

mass_milk <- copy(milk)

mass_milk[, milkwa := av * period]
mass_milk[, milk := new_av * period]
mass_milk[, SD := SD * period]
mass_milk[, consumed := consumed * period]
mass_milk[, sold := sold * period]
mass_milk[, psold := psold * period]
mass_milk[, processed := processed * period]
mass_milk[, processed_new := processed_new * period]
mass_milk[, smd1 := consumed + sold + processed_new]

# ASSUMPTION M7: if estimated milk is zero but dispositions exist, use dispositions as floor
mass_milk[, milk := fifelse(milk == 0 & smd1 > 0, smd1, milk)]
mass_milk[, flag_milk_floor_from_disposition := fifelse(milk == smd1 & smd1 > 0, 1L, 0L)]
mass_milk[, missing := milk - smd1]

# =============================================================================
# SECTION 5: FEED REQUIREMENTS
# =============================================================================

smrum <- data.table(
  feed1 = c(
    "only feeding (no grazing/scavenging)",
    "mainly grazing/scavenging w/ some feeding",
    "only grazing/scavenging",
    "mainly feeding w/ some grazing/scavenging",
    "tethering"
  ),
  feed = c(1, 0.35, 0, 0.65, 0.5),
  grazed = c(0, 0.65, 1, 0.35, 0.5),
  type = "small ruminants"
)

lgrum <- data.table(
  feed1 = c(
    "only feeding (no grazing/scavenging)",
    "mainly grazing/scavenging w/ some feeding",
    "only grazing/scavenging",
    "mainly feeding w/ some grazing/scavenging",
    "tethering"
  ),
  feed = c(1, 0.25, 0, 0.75, 0.5),
  grazed = c(0, 0.75, 1, 0.25, 0.5),
  type = "large ruminants"
)

milkfeed <- rbind(smrum, lgrum)

mass_milk <- setDT(mass_milk)
setnames(mass_milk, "lvstckcat", "type")

mf <- feed_short[mass_milk, on = c("y4_hhid", "type")]
mf[, flag_cross_section_feed_mismatch := fifelse(is.na(feed1_raw), 1L, 0L)]

mf <- milkfeed[mf, on = c("type", "feed1" = "feed1_raw")]
mf[, flag_feed_factor_missing := fifelse(is.na(feed) | is.na(grazed), 1L, 0L)]

# ASSUMPTION M8: 0.7 kg DM per kg milk
mf[, need := milk * 0.7]
mf[, feed_dm := need * feed]
mf[, grazed_dm := need * grazed]
mf[, flag_feed_requirement_applied := fifelse(!is.na(milk), 1L, 0L)]

# =============================================================================
# SECTION 6: LITRE TO KG CONVERSION
# =============================================================================

# ASSUMPTION M9: 1.03 kg per litre
cols_to_convert <- c("milk", "milkwa", "SD", "consumed", "sold", "psold", "processed", "processed_new", "smd1", "missing")
mf[, (paste0(cols_to_convert, "_kg")) := lapply(.SD, function(x) x * 1.03), .SDcols = cols_to_convert]
mf[, flag_milk_conversion_applied := 1L]

saveRDS(milk, here::here("data", "processed", "01", "impute", "milk_imputed.rds"), compress = TRUE)
saveRDS(mass_milk, here::here("data", "processed", "01", "impute", "mass_milk_imputed.rds"), compress = TRUE)
saveRDS(mf, here::here("data", "processed", "01", "impute", "mass_milk_final_imputed.rds"), compress = TRUE)

flag_summary <- function(dt) {
  flag_cols <- names(dt)[grepl("^flag_", names(dt))]
  data.table(
    flag = flag_cols,
    n = vapply(flag_cols, function(col) dt[get(col) == 1L, .N], integer(1))
  )[order(-n)]
}

readr::write_csv(
  as.data.frame(flag_summary(milk)),
  here::here("data", "processed", "01", "impute", "milk_flag_summary.csv")
)

readr::write_csv(
  as.data.frame(flag_summary(mf)),
  here::here("data", "processed", "01", "impute", "mass_milk_flag_summary.csv")
)

message("impute/milk.R: milk outputs imputed and saved.")