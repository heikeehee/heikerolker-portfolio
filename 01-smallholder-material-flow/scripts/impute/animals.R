# =============================================================================
# impute/animals.R
# PURPOSE: Apply animal feed requirement assumptions to estimate feed intake
#          per livestock type, using reported feeding practices as an allocation key
# INPUT:   clean/wa.rds          — carcass breakdown (from clean/animals.R)
#          clean/feed_short.rds  — reported feeding practice per hh-animal type
# OUTPUT:  data/processed/impute/mass_animals.rds
#
# ASSUMPTIONS:
#   1. Feed requirement fractions from:
#        - @MacLeod.2013 (FAO 2013): pigs (p.107), poultry/chickens (p.107)
#        - @Opio.2013 (FAO 2013): small ruminants (p.119), large ruminants (p.117)
#      These are SSA-level averages, not Tanzania-specific.
#      Review if Tanzania-specific feeding data is available.
#   2. Feed fractions represent PROPORTIONS of total DM derived from supplementary
#      feed vs grazing/scavenging, conditional on reported feeding practice.
#   3. "Tethering" replaced by feed2 where available (see clean/animals.R, feed_short.rds).
#      Definition of tethering for feed intake not confirmed in LSMS codebook.
#      Assumed 50/50 split (feed = 0.5, grazed = 0.5) when feed2 unavailable.
#   4. Feed conversion ratio (FCR) source: @Alexander.2016
#      FCR applied as: need = EW (edible weight) × FCR_A16
#      This FCR is edible-weight-based, not live-weight-based.
#   5. Animals lost to disease/injury: feed requirement NOT calculated for these.
#      Only slaughtered animals with positive cons_weight are included.
#   6. Poultry and other animals: same FAO table used for chickens/ducks/other poultry
#      — no species-level differentiation available.
#   7. Fish, honey, and other non-standard livestock: excluded from feed estimation
#      — insufficient reference data.
#
# =============================================================================

library(here)
library(tidyverse)
library(data.table)

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "impute"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# STEP 1: FEED REQUIREMENT ASSUMPTION TABLES
# One table per livestock group. Source cited per table.
# =============================================================================

# 🚩 FLAG ASSUMPTION: Feed fraction tables below are also used in clean/milk.R
# (for the milk feed section). Consolidate into a shared reference file when stable.
# Pigs — @MacLeod.2013 p.107 (backyard)
# 🚩 FLAG ASSUMPTION: Backyard pig values used (not commercial).
# Assumes all Tanzanian NPS pig-keeping is backyard/smallholder.
pork <- data.table(
  feed1  = c("only feeding (no grazing/scavenging)",
             "mainly grazing/scavenging w/ some feeding",
             "only grazing/scavenging",
             "mainly feeding w/ some grazing/scavenging",
             "tethering"),
  feed   = c(1, 0.2, 0, 0.8, 0.5),   # proportion of DM from supplementary feed
  grazed = c(0, 0.8, 1, 0.2, 0.5),   # proportion of DM from grazing/scavenging
  type   = "pigs"
)

# Poultry (chickens/ducks) — @MacLeod.2013 p.107 (backyard)
# 🚩 FLAG ASSUMPTION: Same table for all poultry categories (chickens, ducks, other).
# No species-level differentiation in GYGA or FAO Tier 1 tables for Tanzania.
chicken <- data.table(
  feed1  = c("only feeding (no grazing/scavenging)",
             "mainly grazing/scavenging w/ some feeding",
             "only grazing/scavenging",
             "mainly feeding w/ some grazing/scavenging",
             "tethering"),
  type   = "poultry",
  feed   = c(1, 0.4, 0, 0.6, 0.5),
  grazed = c(0, 0.6, 1, 0.4, 0.5)
)

# Small ruminants (goats/sheep) — @Opio.2013 p.119
# 🚩 FLAG ASSUMPTION: Same fractions for both milk-producing and meat-only small ruminants.
# Opio.2013 p.119 does not differentiate production system for small ruminants.
smrum <- data.table(
  feed1  = c("only feeding (no grazing/scavenging)",
             "mainly grazing/scavenging w/ some feeding",
             "only grazing/scavenging",
             "mainly feeding w/ some grazing/scavenging",
             "tethering"),
  type   = "small ruminants",
  feed   = c(1, 0.35, 0, 0.65, 0.5),
  grazed = c(0, 0.65, 1, 0.35, 0.5)
)

# Large ruminants (cattle) — @Opio.2013 p.117
# 🚩 FLAG ASSUMPTION: Same FCR for dairy and beef cattle.
# Opio.2013 p.117 uses a combined value; dairy FCR likely differs.
# Review if milk-producing cattle should use a separate FCR (see clean/milk.R).
lgrum <- data.table(
  feed1  = c("only feeding (no grazing/scavenging)",
             "mainly grazing/scavenging w/ some feeding",
             "only grazing/scavenging",
             "mainly feeding w/ some grazing/scavenging",
             "tethering"),
  type   = "large ruminants",
  feed   = c(1, 0.25, 0, 0.75, 0.5),   # Opio.2013 p.117
  grazed = c(0, 0.75, 1, 0.25, 0.5)
)

feeds <- bind_rows(pork, chicken, smrum, lgrum)

feeds <- upData(feeds, labels = .q(
  feed   = "Proportion of DM derived from supplementary feed",
  grazed = "Proportion of DM derived from grazing/scavenging"
))

# =============================================================================
# STEP 2: LOAD CLEANED DATA
# =============================================================================

wa <- readRDS(here::here("data", "processed", "clean", "wa.rds"))
f  <- readRDS(here::here("data", "processed", "clean", "feed_short.rds"))

# =============================================================================
# STEP 3: MERGE FEEDING PRACTICE WITH CARCASS DATA AND APPLY FEED FACTORS
# =============================================================================

# Join reported feeding practice to animal records
af <- f[wa, on = c("y4_hhid", "type")]

# Apply feed fractions from FAO tables
af <- feeds[af, on = c("type", "feed1")]

# Compute absolute feed quantities (DM)
af <- upData(af,
  feed   = need * feed,     # kg DM from supplementary feed
  grazed = need * grazed,   # kg DM from grazing/scavenging
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

# 🚩 FLAG EXCLUSION: Animals with no matched feeding practice (feed1 == NA)
# will have feed == NA. Profile these records — they may be "other animals" (rabbits,
# donkeys, dogs, hare) which are not in the FAO tables and are excluded from
# feed estimation. Decision required: impute from a surrogate type, or leave as NA.
no_feed_match <- af %>% filter(is.na(feed) & !is.na(type)) %>%
  distinct(type, lvstckid)
if (nrow(no_feed_match) > 0) {
  message("impute/animals.R: ", nrow(no_feed_match),
          " animal type(s) with no feed fraction match (see FAO table coverage):")
  print(no_feed_match)
}

# =============================================================================
# STEP 4: FINALISE AND SAVE
# =============================================================================

mass_animals <- af %>%
  select(y4_hhid, type, lvstckid,
         need, feed, grazed,
         slaughter, total_weight = sl_weight, cons_weight, sold_weight,
         ew, meat, offal, hides, inedible) %>%
  mutate_at(c(4:15), as.numeric)  # ensure numeric (labelled attributes removed)

saveRDS(mass_animals,
        here::here("data", "processed", "impute", "mass_animals.rds"),
        compress = TRUE)

message("impute/animals.R: feed imputation complete. ",
        nrow(mass_animals), " animal records processed.")
