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
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "clean"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# SECTION 1: HOUSEHOLD IDENTIFIERS (hh_sec_a)
# =============================================================================

hh_sec_a <- raw$hh_sec_a

roster <- hh_sec_a |>
  clean_up() |>
  rename(
    region      = hh_a01_2,
    district    = hh_a02_2,
    stratum     = strataid,
    urban_rural = y4_rural
  ) |>
  select(y4_hhid, region, district, stratum, urban_rural, clusterid, y4_weights) |>
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

ag_flags <- ag_filters |>
  clean_up() |>
  mutate(
    grew_crops  = dplyr::case_when(
      ag2a_01 == "yes" ~ TRUE,
      ag2a_01 == "no"  ~ FALSE,
      TRUE             ~ NA
    ),
    did_process = dplyr::case_when(
      ag10_01 == "yes" ~ TRUE,
      ag10_01 == "no"  ~ FALSE,
      TRUE             ~ NA
    )
  ) |>
  select(y4_hhid, grew_crops, did_process)

# =============================================================================
# SECTION 3: LIVESTOCK FLAGS (lf_filters)
# Ground truth for structural zero classification throughout the pipeline
# =============================================================================
lf_filters <- raw$lf_filters

# 🚩 FLAG [DATA]: lf08_09 uses character coding ("yes"/"no"); lf12_01/lf13_01 use
# numeric coding (1 = yes, 2 = no). Inconsistent within the same module.
# Confirm against NPS4 codebook before publication.

lf_flags <- lf_filters |>
  clean_up() |>
  mutate(
    # Recode sentinel values — numeric columns only
    across(where(is.numeric), ~ if_else(. %in% c(99, 999, -9, -99), NA_real_, .))
  ) |>
  mutate(
    # 🚩 FLAG [DATA]: mixed coding within lf_filters module.
    # lf08_09, lf13_01 → character ("yes"/"no")
    # lf12_01          → numeric (1 = yes, 2 = no)
    # Confirmed against count() output — verify against NPS4 codebook before publication.
    owned_animals = case_when(
      lf08_09 == "yes" ~ TRUE,
      lf08_09 == "no"  ~ FALSE,
      TRUE             ~ NA
    ),
    caught_fish = case_when(
      lf12_01 == 1 ~ TRUE,
      lf12_01 == 2 ~ FALSE,
      TRUE         ~ NA
    ),
    traded_fish = case_when(
      lf13_01 == "yes" ~ TRUE,
      lf13_01 == "no"  ~ FALSE,
      TRUE             ~ NA
    )
  ) |>
  select(y4_hhid, owned_animals, caught_fish, traded_fish)

# =============================================================================
# SECTION 4: STRUCTURAL ZERO RULE
# Documented here — applied in 04_build_households.R via these flags
# =============================================================================

# If grew_crops    == FALSE → harvest quantities = 0 (structural zero, not missing)
# If owned_animals == FALSE → animal quantities  = 0 (structural zero, not missing)
# If did_process   == FALSE → processing quantities = 0 (structural zero, not missing)
# expand for livestock and fish

# 🚩 FLAG [ASSUMPTION]: participation = FALSE implies structural zero — confirm no cases
#    where participation flag = FALSE but quantities > 0 (would indicate data error).
#    Profile in 05_exclusions_audit.R: E_structural_zero_guard.

# =============================================================================
# SECTION 4: JOIN ROSTER AND PARTICIPATION FLAGS
# =============================================================================

roster_full <- roster |>
  left_join(ag_flags, by = "y4_hhid") %>% 
  left_join(lf_flags, by = "y4_hhid")

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
message("  Caught fish:     ", sum(roster_full$caught_fish, na.rm = TRUE))
message("  Traded fish:     ", sum(roster_full$traded_fish, na.rm = TRUE))
message("  Did process:       ", sum(roster_full$did_process,   na.rm = TRUE))
