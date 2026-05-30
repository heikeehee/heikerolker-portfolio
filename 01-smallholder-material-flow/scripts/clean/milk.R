# =============================================================================
# clean/milk.R
# PURPOSE: Clean milk production survey section and create diagnostic outputs
# INPUT:   raw$milk from 01_load_raw.R
#          clean/animals_fin.rds (for cross-referencing milking numbers)
# OUTPUT:  data/processed/01/clean/milk.rds
#          data/processed/01/clean/excl_milk.csv
# SECTION: lf_sec_06 — livestock milk production (Section 6)
# NOTE:    Clean stage only. Standardise, derive diagnostics, and flag issues.
#          Any repair, fallback, uncertainty, feed requirement, or unit conversion
#          belongs in impute/milk.R.
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "01", "clean"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# SECTION 1: LOAD AND RENAME (lf_sec_06)
# =============================================================================

lf_sec_06 <- raw$milk$lf_sec_06
milk <- clean_up(lf_sec_06)

milk <- upData(
  milk,
  rename = .q(
    lf06_01   = milked,
    lf06_02   = length,
    lf06_03   = av_raw,
    lf06_04_2 = hi_raw,
    lf06_05_2 = lo_raw,
    lf06_07   = consumed_raw,
    lf06_08   = sold_raw,
    lf06_09   = processed_raw,
    lf06_10   = psold_raw,
    lf06_11   = value_raw,
    lf06_12_1 = buyer1,
    lf06_12_2 = buyer2
  ),
  labels = .q(
    milked        = "Number of animals milked in past 12 mo",
    length        = "Average number of months animals were milked for",
    av_raw        = "Average milk production per day per type of animal, as reported",
    hi_raw        = "Highest milk production, as reported",
    lo_raw        = "Lowest milk production, as reported",
    consumed_raw  = "Quantity consumed per day, as reported",
    sold_raw      = "Quantity sold per day, as reported",
    processed_raw = "Quantity processed per day, as reported",
    psold_raw     = "Quantity of milk products sold per day, as reported",
    value_raw     = "Value of milk sales, as reported"
  )
)

# =============================================================================
# SECTION 2: CROSS-REFERENCE MILKABLE ANIMALS
# animals_sub is assumed to contain the milkability flag
# =============================================================================

animals_sub <- readRDS(here::here("data", "processed", "01", "clean", "animals_fin.rds"))

milk_support <- unique(
  animals_sub[, .(
    y4_hhid,
    lvstckcat = type,
    max_owned,
    flag_milk_animal
  )]
)

milk_support <- milk_support[flag_milk_animal == 1,
                            .(milkable = sum(max_owned, na.rm = TRUE)),
                            by = .(y4_hhid, lvstckcat)
]

milk <- merge(
  milk,
  milk_support,
  by = c("y4_hhid", "lvstckcat"),
  all.x = TRUE
)

milk[, flag_milk_support_missing := fifelse(is.na(milkable) & milked > 0, 1L, 0L)]
milk[, flag_section_mismatch_milked_gt_owned := fifelse(
  !is.na(milked) & !is.na(milkable) & milked > milkable,
  1L, 0L
)]

message("flag_milk_support_missing: ", milk[flag_milk_support_missing == 1L, .N],
        " rows where milk section record has no matching animal support row")
message("flag_section_mismatch_milked_gt_owned: ", milk[flag_section_mismatch_milked_gt_owned == 1L, .N],
        " rows where milked animals exceed max owned for category")

# Keep only records flagged as milkable
milk <- milk[is.na(milkable) | milkable == 1]

# =============================================================================
# SECTION 3: CLEAN-STAGE FLAGS
# =============================================================================
milk[, flag_hh_milking := fifelse(milked > 0, 1L, 0L)]
milk[, flag_av_missing := fifelse(milked > 0 & is.na(av_raw), 1L, 0L)]
milk[, flag_hi_missing := fifelse(milked > 0 & is.na(hi_raw), 1L, 0L)]
milk[, flag_lo_missing := fifelse(milked > 0 & is.na(lo_raw), 1L, 0L)]
milk[, flag_length_missing := fifelse(milked > 0 & is.na(length), 1L, 0L)]
milk[, flag_fix_processing_input := fifelse(processed_raw < psold_raw, 1L, 0L)]
milk[, flag_daily_output_implausible := fifelse(milked == 1 & av_raw > 6, 1L, 0L)]

milk[, flag_processed_value_missing := fifelse(
  (!is.na(psold_raw) | psold_raw > 0) & (is.na(value_raw) | value_raw == 0),
  1L, 0L
)]

milk[, disposition_raw := rowSums(.SD, na.rm = TRUE), .SDcols = c("consumed_raw", "sold_raw", "processed_raw")]
milk[, flag_disposition_present_but_av_missing := fifelse(
  is.na(av_raw) & disposition_raw > 0,
  1L, 0L
)]

milk[, flag_disposition_exceeds_production := fifelse(disposition_raw > av_raw, 1L, 0L)]
milk[, flag_period_implausible := fifelse(!is.na(length) & length > 10 & milked == 1, 1L, 0L)]
milk[, flag_zero_milked_with_output := fifelse(
  !is.na(milked) & milked == 0 &
    rowSums(.SD, na.rm = TRUE) > 0,
  1L, 0L
), .SDcols = c("av_raw", "consumed_raw", "sold_raw", "processed_raw", "psold_raw")]

message("flag_hh_milking: ", milk[flag_hh_milking == 1L, .N],
        " rows with households milking animals")
message("flag_manual_av_fix_needed: ", milk[flag_manual_av_fix_needed == 1L, .N],
        " rows where av_raw will need household-specific repair in impute")
message("flag_av_missing: ", milk[flag_av_missing == 1L, .N],
        " rows where av_raw is missing")
message("flag_hi_missing: ", milk[flag_hi_missing == 1L, .N],
        " rows where hi_raw is missing")
message("flag_lo_missing: ", milk[flag_lo_missing == 1L, .N],
        " rows where lo_raw is missing")
message("flag_length_missing: ", milk[flag_length_missing == 1L, .N],
        " rows where length is missing")
message("flag_processed_value_missing: ", milk[flag_processed_value_missing == 1L, .N],
        " rows where processed sold value is missing")
message("flag_disposition_present_but_av_missing: ", milk[flag_disposition_present_but_av_missing == 1L, .N],
        " rows where dispositions exist but av_raw is missing")
message("flag_period_implausible: ", milk[flag_period_implausible == 1L, .N],
        " rows where milking length exceeds 12 months")
message("flag_zero_milked_with_output: ", milk[flag_zero_milked_with_output == 1L, .N],
        " rows where no animals milked are reported but milk outputs exist")
message("flag_fix_processing_input: ", milk[flag_fix_processing_input == 1L, .N],
        " rows where processed_raw is lower than psold_raw")
message("flag_daily_output_implausible: ", milk[flag_daily_output_implausible == 1L, .N],
        " rows where milked = 1 and average milk output above 6l")
message("flag_disposition_exceeds_production: ", milk[flag_disposition_exceeds_production == 1L, .N],
        " rows where sum of disposition exceeds average production")

saveRDS(milk, here::here("data", "processed", "01", "clean", "milk.rds"), compress = TRUE)

flag_cols <- names(milk)[grepl("^flag_", names(milk))]
flag_summary <- data.table(
  flag = flag_cols,
  n = vapply(flag_cols, function(col) milk[get(col) == 1L, .N], integer(1))
)[order(-n)]

message("----- Flag summary: milk -----")
print(flag_summary)

readr::write_csv(
  as.data.frame(flag_summary),
  here::here("data", "processed", "01", "clean", "milk_flag_summary.csv")
)


message("clean/milk.R: milk outputs saved.")