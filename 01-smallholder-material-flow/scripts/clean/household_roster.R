# =============================================================================
# clean/household_roster.R
# PURPOSE: Clean household roster and agricultural participation filters
# INPUT:   raw$hh_sec_a   — household section A (identification, location)
#          raw$ag_filters — agricultural participation module
# OUTPUT:  data/processed/clean/household_roster.rds
#
# This is the SPINE of the pipeline — all other sections join to this.
# y4_hhid must be unique here — one row per household.
# Agricultural participation flags (grew_crops, owned_animals, did_process) are
# the ground truth for structural zero classification throughout the pipeline.
#
# ASSUMPTIONS:
#   All variable names below derived from LSMS-ISA Tanzania NPS Wave 4 codebook.
#   Where names could not be confirmed from archive scripts, a 🚩 FLAG [BOUNDARY]
#   comment is placed and the pipeline continues with NA for that variable.
# =============================================================================

library(tidyverse)
library(here)

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "clean"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# SECTION 1: HOUSEHOLD IDENTIFIERS (hh_sec_a)
# =============================================================================

hh_sec_a <- raw$hh_sec_a

# 🚩 FLAG [BOUNDARY]: variable names below taken from LSMS-ISA Tanzania NPS Wave 4
# codebook conventions (hh_a01_1 = region, hh_a01_2 = district, hh_a02_1 = stratum,
# hh_a15 = urban/rural indicator). Confirm against actual dta labels before stage 3.
# If variable names differ in raw data, update the rename() call below.

roster <- hh_sec_a |>
  clean_up() |>
  rename(
    # Confirm these variable names from the dta codebook:
    # 🚩 FLAG [BOUNDARY]: hh_a01_1 assumed = region — confirm codebook
    region      = hh_a01_1,
    # 🚩 FLAG [BOUNDARY]: hh_a01_2 assumed = district — confirm codebook
    district    = hh_a01_2,
    # 🚩 FLAG [BOUNDARY]: hh_a02_1 assumed = stratum — confirm codebook
    stratum     = hh_a02_1,
    # 🚩 FLAG [BOUNDARY]: hh_a15 assumed = urban/rural — confirm codebook
    urban_rural = hh_a15
  ) |>
  select(y4_hhid, region, district, stratum, urban_rural) |>
  distinct(y4_hhid, .keep_all = TRUE)

# 🚩 FLAG [EXCLUSION]: duplicate y4_hhid in hh_sec_a — profile in 05_exclusions_audit.R
n_dup_roster <- sum(duplicated(hh_sec_a$y4_hhid))
if (n_dup_roster > 0) {
  message("clean/household_roster.R: ", n_dup_roster,
          " duplicate y4_hhid in hh_sec_a — first occurrence retained")
}

# =============================================================================
# SECTION 2: AGRICULTURAL PARTICIPATION FLAGS (ag_filters)
# Ground truth for structural zero classification throughout the pipeline
# =============================================================================

ag_filters <- raw$ag_filters

# 🚩 FLAG [BOUNDARY]: participation variable names below are based on LSMS-ISA
# NPS Wave 4 ag_filters.dta conventions. These files vary by wave.
# Common coding: 1 = yes, 2 = no (not 0/1).
# Confirm coding scheme against codebook before using grew_crops etc. as guards.

# 🚩 FLAG [ASSUMPTION]: participation flag coding — confirm against codebook
# (1 = yes, 2 = no is the standard NPS coding — not 1/0)
ag_flags <- ag_filters |>
  clean_up() |>
  mutate(
    # 🚩 FLAG [BOUNDARY]: ag_k01 assumed = crop participation — confirm codebook
    grew_crops    = if_else(ag_k01    == 1, TRUE, FALSE, missing = NA),
    # 🚩 FLAG [BOUNDARY]: ag_k02 assumed = animal ownership — confirm codebook
    owned_animals = if_else(ag_k02    == 1, TRUE, FALSE, missing = NA),
    # 🚩 FLAG [BOUNDARY]: ag_k03 assumed = processing participation — confirm codebook
    did_process   = if_else(ag_k03    == 1, TRUE, FALSE, missing = NA),
    # Recode sentinel values (NPS uses 99, 999, -9, -99 for missing)
    across(where(is.numeric), ~ if_else(. %in% c(99, 999, -9, -99), NA_real_, .))
  ) |>
  select(y4_hhid, grew_crops, owned_animals, did_process)

# =============================================================================
# SECTION 3: STRUCTURAL ZERO RULE
# Documented here — applied in 04_build_households.R via these flags
# =============================================================================

# If grew_crops    == FALSE → harvest quantities = 0 (structural zero, not missing)
# If owned_animals == FALSE → animal quantities  = 0 (structural zero, not missing)
# If did_process   == FALSE → processing quantities = 0 (structural zero, not missing)

# 🚩 FLAG [ASSUMPTION]: participation = FALSE implies structural zero — confirm no cases
#    where participation flag = FALSE but quantities > 0 (would indicate data error).
#    Profile in 05_exclusions_audit.R: E_structural_zero_guard.

# =============================================================================
# SECTION 4: JOIN ROSTER AND PARTICIPATION FLAGS
# =============================================================================

roster_full <- roster |>
  left_join(ag_flags, by = "y4_hhid")

# 🚩 FLAG [EXCLUSION]: households in hh_sec_a with no ag_filters match —
#    profile in 05_exclusions_audit.R.
n_no_match <- sum(is.na(roster_full$grew_crops))
message("clean/household_roster.R: ", n_no_match,
        " households in hh_sec_a with no ag_filters match (grew_crops = NA)")

# =============================================================================
# SECTION 5: VALIDATE AND SAVE
# =============================================================================

# y4_hhid must be unique — one row per household (pipeline spine requirement)
stopifnot("y4_hhid not unique in household_roster" = !anyDuplicated(roster_full$y4_hhid))

saveRDS(roster_full,
        here::here("data", "processed", "clean", "household_roster.rds"),
        compress = TRUE)

message("clean/household_roster.R: Household roster saved")
message("  Total households:  ", nrow(roster_full))
message("  Grew crops:        ", sum(roster_full$grew_crops,    na.rm = TRUE))
message("  Owned animals:     ", sum(roster_full$owned_animals, na.rm = TRUE))
message("  Did process:       ", sum(roster_full$did_process,   na.rm = TRUE))
