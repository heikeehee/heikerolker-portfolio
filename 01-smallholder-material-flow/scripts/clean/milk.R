# =============================================================================
# clean/milk.R
# PURPOSE: Clean milk production and destination survey section
# INPUT:   raw$milk from 01_load_raw.R
#          clean/animals_fin.rds (for cross-referencing milking numbers)
#          clean/feed_short.rds  (for feed requirement calculation)
# OUTPUT:  data/processed/clean/milk.rds        (cleaned milk, cleaned estimates)
#          data/processed/clean/mass_milk.rds   (annualised milk with uncertainty)
#          data/processed/clean/excl_milk.csv   (exclusion flags)
# SECTION: lf_sec_06 — livestock milk production (Section 6)
# NOTE:    Feed requirement imputation uses FAO factors — see impute/animals.R
#          for the canonical feed table. The feed calculation in this script
#          uses the same logic; consider refactoring to share that table.
# =============================================================================

library(here)
library(tidyverse)
library(data.table)

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "clean"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# SECTION 1: LOAD AND RENAME (lf_sec_06)
# =============================================================================

lf_sec_06 <- raw$milk$lf_sec_06
milk       <- clean_up(lf_sec_06)

# Manual fixes for three households with missing average milk production
# 🚩 FLAG ASSUMPTION: Three households with missing average (lf06_03) filled
# by inspection of raw data — hardcoded by design.
# Review if raw data changes; see archived 04_Milk.Rmd for rationale.
milk <- milk %>%
  mutate(
    # 1001-001: only lowest value reported — use lo as average
    lf06_03 = ifelse(y4_hhid == "1001-001", lf06_05_2, lf06_03),
    # 1002-001: no average but hi and lo exist — use midpoint
    lf06_03 = ifelse(y4_hhid == "1002-001", (lf06_05_2 + lf06_04_2) / 2, lf06_03),
    # 2943-001: only consumption reported — derive average from sum
    lf06_03 = ifelse(y4_hhid == "2943-001", lf06_07 + lf06_08 + lf06_10, lf06_03)
  )

milk <- upData(milk,
  rename = .q(
    lf06_01  = milked,
    lf06_02  = length,
    lf06_03  = av,
    lf06_04_2 = hi,
    lf06_05_2 = lo,
    lf06_07  = consumed,
    lf06_08  = sold,
    lf06_09  = processed,
    lf06_10  = psold,
    lf06_11  = value,
    lf06_12_1 = buyer1,
    lf06_12_2 = buyer2
  ),

  # Derived annualised quantities
  # 🚩 FLAG UNIT: 30.437 days/month — standard average, not Tanzania-specific.
  period      = length * 30.437,        # days milked per production period
  milk        = period * av,            # total annual milk (using average)
  milk_lo     = period * lo,
  milk_hi     = period * hi,
  consumed_a  = consumed  * period,
  sold_a      = sold      * period,
  processed_a = processed * period,
  psold_a     = psold     * period,
  output      = milk / milked,          # milk per animal
  ava         = av / milked,            # average per animal
  value_a     = value * period,

  labels = .q(
    milked      = "Number of animals milked in past 12 mo",
    length      = "Average number of mo animals were milked for",
    av          = "Average milk production per day per type of animal",
    hi          = "Highest milk production",
    lo          = "Lowest milk production",
    consumed    = "Quantity consumed per day",
    sold        = "Quantity sold per day",
    processed   = "Quantity of milk converted into produce per day",
    psold       = "Quantity of milk products sold per day",
    period      = "Period of milking",
    milk        = "Total annual quantity of milk produced",
    milk_lo     = "Total estimate with lowest month",
    milk_hi     = "Total estimate with highest month",
    consumed_a  = "Annual consumption based on milking period",
    sold_a      = "Annual sales based on milking period",
    output      = "Estimate of milk per animal",
    ava         = "Average quantity per animal"
  ),
  units = .q(
    av          = `l/day`,
    hi          = `l/day`,
    lo          = `l/day`,
    consumed    = `l/day`,
    sold        = `l/day`,
    processed   = `l/day`,
    psold       = `l/day`,
    milk        = l,
    consumed_a  = l,
    sold_a      = l,
    ava         = l
  )
)

# Keep only milkable species (large and small ruminants)
# 🚩 FLAG EXCLUSION: Non-ruminant livestock categories dropped from milk section.
# Confirm no milkable animals (e.g. camels) are coded under other categories
# — profile in 05_exclusions_audit.R
milk <- milk[lvstckcat == "large ruminants" | lvstckcat == "small ruminants"]

saveRDS(milk, here::here("data", "processed", "clean", "milk.rds"), compress = TRUE)

# =============================================================================
# SECTION 2: MILK QUANTITY RECONCILIATION AND UNCERTAINTY
# Derive a representative average production estimate using av, hi, lo, and
# the sum of reported dispositions (consumed + sold + processed)
# =============================================================================

cleaned_data <- milk %>%
  mutate(
    # Replace processed with psold if processed < psold (sold > what was processed — data inconsistency)
    # 🚩 FLAG ASSUMPTION: processed = psold when processed < psold.
    # Treats psold as a lower bound on processed. Review if processing and sales
    # data are more reliable than assumed here.
    processed_new    = ifelse(processed < psold, psold, processed),
    processed_new    = replace_na(processed_new, 0),
    smd1             = consumed + sold + processed_new,   # sum of all dispositions

    # Fallback average: use smd1 when av is missing
    av_with_fallback = ifelse(is.na(av), smd1, av),

    # Multiple average estimates (documented for transparency)
    simple_av    = (av_with_fallback + hi + lo) / 3,
    weighted_av  = ifelse(is.na(av), smd1, 0.8 * av + 0.2 * smd1),
    geo_av       = ifelse(is.na(av), sqrt(smd1 * smd1), sqrt(av * smd1)),

    # Constrain average to plausible range [lo, hi]
    corrected_avg = ifelse(
      is.na(av_with_fallback) | is.na(lo) | is.na(hi),
      av_with_fallback,
      pmin(pmax(av_with_fallback, lo), hi)
    ),
    corrected_min = ifelse(is.na(lo) | is.na(corrected_avg), lo, pmin(lo, corrected_avg)),
    corrected_max = ifelse(is.na(hi) | is.na(corrected_avg), hi, pmax(hi, corrected_avg)),

    # Uncertainty: range / 4 approximation (assumes normal distribution)
    # 🚩 FLAG ASSUMPTION: SD = range / 4. Standard approximation — not survey-derived.
    range = ifelse(is.na(corrected_max) | is.na(corrected_min), NA, corrected_max - corrected_min),
    SD    = ifelse(is.na(range), NA, range / 4),

    # Representative production value
    # 🚩 FLAG ASSUMPTION: new_av = 0.2*min + 0.6*avg + 0.2*max (PERT-like weighting).
    # Method chosen as it gave fewest exclusions (n=92) vs alternatives tested.
    # See archived 04_Milk.Rmd for comparison of methods.
    new_av = ifelse(
      av == smd1, av,
      0.2 * corrected_min + 0.6 * corrected_avg + 0.2 * corrected_max
    )
  )

# Exclusion flags
excl_milk <- cleaned_data %>%
  mutate(
    processed_new = ifelse(processed < psold, psold, processed),
    processed_new = replace_na(processed_new, 0),
    smd1          = consumed + sold + processed_new
  ) %>%
  filter(milked > 0) %>%
  select(y4_hhid, lvstckcat, corrected_avg, corrected_min, corrected_max,
         ends_with("av"), av_with_fallback, SD, consumed, sold, processed, psold, period, milked) %>%
  dplyr::rename(mean = new_av) %>%
  mutate(
    processed_new = ifelse(processed < psold, psold, processed),
    processed_new = replace_na(processed_new, 0),
    smd1          = consumed + sold + processed_new
  ) %>%
  mutate(
    excl = fcase(
      # 🚩 FLAG EXCLUSION: Exclusion rules for milk — thresholds based on
      # physiological plausibility and manual inspection. Not codebook-specified.
      # Profile excluded households in 05_exclusions_audit.R.
      period > 310 & milked == 1,                                          "Implausible",
      smd1 > 7    & milked == 1,                                           "Implausible",
      mean * 1.2 < consumed | mean * 1.2 < sold | mean * 1.2 < processed_new, "Data inconsistent",
      smd1 > mean * 1.5,                                                   "Excessive milk use",
      smd1 <= mean * 0.5,                                                  "Milk unaccounted"
    ),
    item = paste("milk", lvstckcat, sep = " - ")
  ) %>%
  select(y4_hhid, item, excl)

write.csv(excl_milk,
          here::here("data", "processed", "clean", "excl_milk.csv"),
          row.names = FALSE)

# =============================================================================
# SECTION 3: ANNUALISED MASS MILK
# =============================================================================

mass_milk <- cleaned_data %>%
  mutate_if(is.numeric, ~replace(., is.na(.), 0)) %>%
  dplyr::rename(type = lvstckcat) %>%
  mutate(
    milkwa      = av * period,             # unadjusted annual milk (for comparison)
    milk        = new_av * period,         # adjusted annual milk using new_av
    SD          = SD * period,
    consumed    = consumed  * period,
    sold        = sold      * period,
    psold       = psold     * period,
    processed   = processed * period,
    processed_new = ifelse(processed < psold, psold, processed),
    smd1        = consumed + sold + processed_new,
    # If milk estimate is 0 but dispositions exist, use dispositions as floor
    milk        = ifelse(milk == 0 & smd1 > 0, smd1, milk),
    missing     = milk - smd1
  )

saveRDS(mass_milk, here::here("data", "processed", "clean", "mass_milk.rds"), compress = TRUE)

# =============================================================================
# SECTION 4: MILK FEED REQUIREMENTS
# 🚩 FLAG CROSS-SECTION: feed_short from clean/animals.R required here.
# Feed factors from @Opio.2013 — same approach as in impute/animals.R.
# Consider consolidating feed tables into a shared reference object.
# =============================================================================

f <- readRDS(here::here("data", "processed", "clean", "feed_short.rds"))

# Feed fractions by animal type and feeding practice
# Source: @Opio.2013 p.119 (small ruminants), p.117 (dairy cattle)
# 🚩 FLAG ASSUMPTION: Feed fraction tables below are duplicated in impute/animals.R.
# Consolidate into a shared reference (e.g. data/reference/feed_fractions.csv)
# when both scripts are stable — maintenance risk if assumptions change.
smrum <- data.table(
  feed1  = c("only feeding (no grazing/scavenging)",
             "mainly grazing/scavenging w/ some feeding",
             "only grazing/scavenging",
             "mainly feeding w/ some grazing/scavenging",
             "tethering"),
  feed   = c(1, 0.35, 0, 0.65, 0.5),
  grazed = c(0, 0.65, 1, 0.35, 0.5),
  type   = "small ruminants"
)

lgrum <- data.table(
  feed1  = c("only feeding (no grazing/scavenging)",
             "mainly grazing/scavenging w/ some feeding",
             "only grazing/scavenging",
             "mainly feeding w/ some grazing/scavenging",
             "tethering"),
  feed   = c(1, 0.25, 0, 0.75, 0.5),
  grazed = c(0, 0.75, 1, 0.25, 0.5),
  type   = "large ruminants"
)

milkfeed <- bind_rows(smrum, lgrum)

milk3    <- setDT(mass_milk)
mf       <- f[milk3, on = c("y4_hhid", "type")]
mf       <- milkfeed[mf, on = c("type", "feed1")]

# 🚩 FLAG ASSUMPTION: Feed conversion ratio 0.7 kg DM / kg milk from @Alexander.2016.
# Applied uniformly to small and large ruminants — no differentiation.
# Review with domain expert; consider separate FCRs for large vs small ruminants.
mf <- upData(mf,
  need   = milk * 0.7,
  feed   = need * feed,
  grazed = need * grazed,
  labels = .q(
    feed   = "Quantity of feed consumed in DM",
    grazed = "Quantity grazed/scavenged in DM",
    need   = "Quantity DM needed to produce milk"
  ),
  units = .q(
    feed   = "kg DM",
    grazed = "kg DM",
    need   = "kg DM",
    milk   = kg
  ),
  drop = .q(feed1)
)

# 🚩 FLAG UNIT: milk quantities converted litre → kg using factor 1.08.
# Density of fresh whole milk; codebook likely records litres.
# Conversion factor not codebook-specified — verify against LSMS documentation.
mass_milk_final <- mf %>%
  mutate(across(milk_lo:psold, ~.x * 1.08))  # litre → kg for milk columns

saveRDS(mass_milk_final, here::here("data", "processed", "clean", "mass_milk_final.rds"),
        compress = TRUE)

message("clean/milk.R: milk outputs saved.")
