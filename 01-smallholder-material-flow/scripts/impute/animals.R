# =============================================================================
# impute/animals.R
# PURPOSE: Apply animal feed requirement assumptions to estimate feed intake
#          per livestock type, using reported feeding practices as an allocation key
# INPUT:   clean/wa.rds          — carcass breakdown (from clean/animals.R)
#          clean/feed_short.rds  — cleaned feeding practice per hh-animal type
# OUTPUT:  data/processed/01/impute/mass_animals.rds
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "01", "impute"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# STEP 1: FEED REQUIREMENT ASSUMPTION TABLES
# =============================================================================

pork <- data.table(
  feed1  = c(
    "only feeding (no grazing/scavenging)",
    "mainly grazing/scavenging w/ some feeding",
    "only grazing/scavenging",
    "mainly feeding w/ some grazing/scavenging",
    "tethering"
  ),
  feed   = c(1, 0.2, 0, 0.8, 0.5),
  grazed = c(0, 0.8, 1, 0.2, 0.5),
  type   = "pigs"
)

chicken <- data.table(
  feed1  = c(
    "only feeding (no grazing/scavenging)",
    "mainly grazing/scavenging w/ some feeding",
    "only grazing/scavenging",
    "mainly feeding w/ some grazing/scavenging",
    "tethering"
  ),
  type   = "poultry",
  feed   = c(1, 0.4, 0, 0.6, 0.5),
  grazed = c(0, 0.6, 1, 0.4, 0.5)
)

smrum <- data.table(
  feed1  = c(
    "only feeding (no grazing/scavenging)",
    "mainly grazing/scavenging w/ some feeding",
    "only grazing/scavenging",
    "mainly feeding w/ some grazing/scavenging",
    "tethering"
  ),
  type   = "small ruminants",
  feed   = c(1, 0.35, 0, 0.65, 0.5),
  grazed = c(0, 0.65, 1, 0.35, 0.5)
)

lgrum <- data.table(
  feed1  = c(
    "only feeding (no grazing/scavenging)",
    "mainly grazing/scavenging w/ some feeding",
    "only grazing/scavenging",
    "mainly feeding w/ some grazing/scavenging",
    "tethering"
  ),
  type   = "large ruminants",
  feed   = c(1, 0.25, 0, 0.75, 0.5),
  grazed = c(0, 0.75, 1, 0.25, 0.5)
)

feeds <- bind_rows(pork, chicken, smrum, lgrum)

# =============================================================================
# STEP 2: LOAD CLEANED DATA
# =============================================================================

wa <- readRDS(here::here("data", "processed", "01", "clean", "wa.rds"))
feed_short <- readRDS(here::here("data", "processed", "01", "clean", "feed_short.rds"))

# =============================================================================
# STEP 3: MERGE FEEDING PRACTICE WITH CARCASS DATA AND APPLY FEED FACTORS
# =============================================================================

af <- feed_short[wa, on = c("y4_hhid", "type")]
af <- feeds[af, on = c("type", "feed1")]

af <- upData(
  af,
  feed   = need * feed,
  grazed = need * grazed,
  labels = .q(
    need   = "Feed requirements in DM for edible weight produced",
    feed   = "Quantity of supplementary feed consumed in DM",
    grazed = "Quantity grazed/scavenged in DM"
  ),
  units = .q(
    need   = "kg DM",
    feed   = "kg DM",
    grazed = "kg DM"
  )
)

af[, flag_missing_feed_match := fifelse(!is.na(type) & is.na(feed), 1L, 0L)]
af[, flag_no_cons_weight := fifelse(is.na(cons_weight) | cons_weight <= 0, 1L, 0L)]

# Keep only records that can meaningfully contribute to feed totals.
mass_animals <- af[flag_no_cons_weight == 0L, .(
  y4_hhid, type, lvstckid, feed1, feed1_raw, feed2_raw,
  need, feed, grazed,
  slaughter, sl_weight, cons_weight, sold_weight,
  ew, meat, offal, hides, inedible,
  flag_tethering_resolved, flag_tethering_retained,
  flag_feed1_unexpected, flag_feed2_unexpected,
  flag_missing_feed_match, flag_no_cons_weight
)]

flag_cols <- names(mass_animals)[grepl("^flag_", names(mass_animals))]
flag_summary <- data.table(
  flag = flag_cols,
  n = vapply(flag_cols, function(col) mass_animals[get(col) == 1L, .N], integer(1))
)[order(-n)]

readr::write_csv(
  as.data.frame(flag_summary),
  here::here("data", "processed", "01", "impute", "mass_animals_flag_summary.csv")
)

saveRDS(
  mass_animals,
  here::here("data", "processed", "01", "impute", "mass_animals.rds"),
  compress = TRUE
)

# =============================================================================
# STEP 3: JOIN FEED PRACTICE WITH CARCASS DATA
# =============================================================================

af <- feed_short[wa, on = c("y4_hhid", "type")]
af <- feeds[af, on = c("type", "feed1")]

# =============================================================================
# STEP 4: APPLY FEED FACTORS
# =============================================================================

af <- upData(
  af,
  feed   = need * feed,
  grazed = need * grazed,
  labels = .q(
    need   = "Feed requirement in dry matter for edible weight produced",
    feed   = "Quantity of supplementary feed consumed in dry matter",
    grazed = "Quantity grazed/scavenged in dry matter"
  ),
  units = .q(
    need   = "kg DM",
    feed   = "kg DM",
    grazed = "kg DM"
  )
)

# FLAG F1: missing feed factor match after join.
af[, flag_missing_feed_match := fifelse(!is.na(type) & is.na(feed), 1L, 0L)]
n_flag_missing_feed_match <- sum(af$flag_missing_feed_match, na.rm = TRUE)
message("flag_missing_feed_match: ", n_flag_missing_feed_match,
        " animal records with no matched feed fraction")

if (n_flag_missing_feed_match > 0) {
  no_feed_match <- af[flag_missing_feed_match == 1L, .SD, .SDcols = c("type", "lvstckid", "feed1")]
  no_feed_match <- unique(no_feed_match[order(type, lvstckid)])
  print(no_feed_match)
}

# FLAG F2: records with need present but no cons_weight; should not be used downstream.
af[, flag_no_cons_weight := fifelse(is.na(cons_weight) | cons_weight <= 0, 1L, 0L)]
n_flag_no_cons_weight <- sum(af$flag_no_cons_weight, na.rm = TRUE)
message("flag_no_cons_weight: ", n_flag_no_cons_weight,
        " animal records without positive cons_weight")

# =============================================================================
# STEP 5: FINALISE OUTPUT
# =============================================================================

mass_animals <- af %>%
  select(
    y4_hhid, type, lvstckid, feed1,
    need, feed, grazed,
    slaughter, sl_weight, cons_weight, sold_weight,
    ew, meat, offal, hides, inedible,
    flag_missing_feed_match, flag_no_cons_weight
  ) %>%
  mutate(across(where(is.labelled), as.numeric))

# FLAG SUMMARY
flag_cols <- names(mass_animals)[grepl("^flag_", names(mass_animals))]
flag_summary <- data.table(
  flag = flag_cols,
  n = vapply(flag_cols, function(col) mass_animals[get(col) == 1L, .N], integer(1))
)[order(-n)]

message("----- Flag summary: mass_animals -----")
print(flag_summary)

readr::write_csv(
  as.data.frame(flag_summary),
  here::here("data", "processed", "01", "impute", "mass_animals_flag_summary.csv")
)

saveRDS(
  mass_animals,
  here::here("data", "processed", "01", "impute", "mass_animals.rds"),
  compress = TRUE
)

message("impute/animals.R: feed allocation complete. ", nrow(mass_animals), " animal records processed.")