# =============================================================================
# 05_exclusions_audit.R
# PURPOSE: Profile all households excluded at each pipeline stage
# INPUT:   data/processed/clean/*.rds + households.rds (stage 3 output)
# OUTPUT:  data/processed/exclusions_summary.rds + summary table
# NOTE:    Run AFTER 04_build_households.R
#          This script changes nothing — it only reports.
# =============================================================================

library(here)
library(tidyverse)
library(data.table)

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "01"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# PRE-LOAD: cleaned section files
# =============================================================================

crops      <- zap_all(readRDS(here::here("data", "processed", "01", "clean", "crops.rds")))
pc         <- zap_all(readRDS(here::here("data", "processed", "01", "clean", "pc.rds")))
plot_det   <- zap_all(readRDS(here::here("data", "processed", "01", "clean", "plot_details.rds")))
animals    <- zap_all(readRDS(here::here("data", "processed", "01", "clean", "animals.rds")))
animals_fin <- zap_all(readRDS(here::here("data", "processed", "01", "clean", "animals_fin.rds")))
excl_animals <- readr::read_csv(here::here("data", "processed", "01", "clean", "excl_animals.csv"),
                                 na = c("", "NA"), show_col_types = FALSE)
produce    <- zap_all(readRDS(here::here("data", "processed", "01", "clean", "produce.rds")))
hides      <- zap_all(readRDS(here::here("data", "processed", "01", "clean", "hides.rds")))
mass_milk  <- zap_all(readRDS(here::here("data", "processed", "01", "clean", "milk.rds")))
excl_milk  <- readr::read_csv(here::here("data", "processed", "01", "clean", "excl_milk.csv"),
                               na = c("", "NA"), show_col_types = FALSE)
crop_disp  <- zap_all(readRDS(here::here("data", "processed", "01", "clean", "crop_disp.rds")))
excl_crops <- readr::read_csv(here::here("data", "processed", "01", "clean", "excl_crops.csv"),
                               na = c("", "NA"), show_col_types = FALSE)
excl_trees <- readr::read_csv(here::here("data", "processed", "01", "clean", "excl_trees.csv"),
                               na = c("", "NA"), show_col_types = FALSE)
excl_eggs  <- readr::read_csv(here::here("data", "processed", "01", "clean", "excl_eggs.csv"),
                               na = c("", "NA"), show_col_types = FALSE)
mass_residue <- zap_all(readRDS(here::here("data", "processed", "01", "clean", "mass_residue.rds")))

# Household roster — loads if available (spine for joining region/wealth)
roster_path <- here::here("data", "processed", "01", "clean", "household_roster.rds")
if (file.exists(roster_path)) {
  roster <- zap_all(readRDS(roster_path))
} else {
  roster <- NULL
  message("05_exclusions_audit.R: household_roster.rds not found — region/wealth joins skipped")
}

# households.rds — available after 04_build_households.R
households_path <- here::here("data", "processed", "01", "households.rds")
if (file.exists(households_path)) {
  households <- zap_all(readRDS(households_path))
} else {
  households <- NULL
  message("05_exclusions_audit.R: households.rds not found — stage 3 stubs skipped")
}

# Helper: safe left join to roster for region breakdown
join_roster <- function(df, by = "y4_hhid") {
  if (!is.null(roster)) left_join(df, select(roster, y4_hhid, region), by = by)
  else df
}

# =============================================================================
# EXCLUSION E01: harvest values set to 0 when harvested == "no"
# Source: clean/crops.R — Section 2, upData() block
# Type: structural zero | missing data — FLAG
# =============================================================================

# Profile: how many crop–plot records have harvested == "no"
excluded_E01 <- crops |>
  filter(harvested == "no") |>
  join_roster()

included_E01 <- crops |>
  filter(harvested != "no" | is.na(harvested)) |>
  join_roster()

profile_E01 <- bind_rows(
  excluded_E01 |> mutate(group = "excluded"),
  included_E01 |> mutate(group = "included")
) |>
  group_by(group) |>
  summarise(
    n            = n(),
    n_households = n_distinct(y4_hhid),
    .groups = "drop"
  )

if (!is.null(roster)) {
  region_E01 <- bind_rows(
    excluded_E01 |> mutate(group = "excluded"),
    included_E01 |> mutate(group = "included")
  ) |>
    group_by(group, region) |>
    summarise(n = n(), .groups = "drop")
  message("E01 — by region:"); print(region_E01)
}

message("E01 — harvest values zeroed when harvested == 'no'")
message("  Excluded records: ", nrow(excluded_E01))
message("  Included records: ", nrow(included_E01))
print(profile_E01)
# 🚩 FLAG [EXCLUSION]: systematic pattern? If yes → backlog B01 (imputation sensitivity)

# =============================================================================
# EXCLUSION E02: area_planted is NA — replaced with area_harvested_new
# Source: clean/crops.R — crop-plot merge section
# Type: missing data
# =============================================================================

excluded_E02 <- pc |>
  as.data.frame() |>
  filter(is.na(area_planted)) |>
  select(y4_hhid, plotnum, cropid, area_planted, area_harvested_new)

message("E02 — area_planted is NA (replaced with area_harvested_new)")
message("  Affected records: ", nrow(excluded_E02))
if (nrow(excluded_E02) > 0) print(excluded_E02)
# 🚩 FLAG [EXCLUSION]: confirm replacement is valid for these specific records

# =============================================================================
# EXCLUSION E03: ag3b_01b == 2 filter on short-season plots
# Source: clean/crops.R — Section 4 (plot details)
# Type: structural (retains only plots active in both seasons)
# Note: == 2 means plot used in both long and short season (double counted without filter)
# =============================================================================

excluded_E03_count <- plot_det |>
  as.data.frame() |>
  filter(season == "short") |>
  nrow()

included_E03_count <- nrow(plot_det |> as.data.frame() |> filter(season == "long"))

message("E03 — ag3b_01b == 2 filter on short-season plots")
message("  Short-season plots retained (both seasons): ", excluded_E03_count)
message("  Long-season plots: ", included_E03_count)
message("  Note: filter retains plots active in both seasons to avoid double-counting")
# 🚩 FLAG [EXCLUSION]: confirm codebook meaning of ag3b_01b == 2

# =============================================================================
# EXCLUSION E04: sentinel 0 applied when gateway question == "no" (animals)
# Source: clean/animals.R — Section 1, upData() block
# Type: structural zero | missing data — FLAG
# =============================================================================

# Profile: proportion of zeros from gateway "no" vs genuinely missing (NA) in key vars
animal_zeros <- animals |>
  as.data.frame() |>
  summarise(
    n_total       = n(),
    n_bought_zero = sum(bought == 0, na.rm = TRUE),
    n_sold_zero   = sum(sold   == 0, na.rm = TRUE),
    n_slaughter_zero = sum(slaughter == 0, na.rm = TRUE),
    n_bought_na   = sum(is.na(bought)),
    n_sold_na     = sum(is.na(sold)),
    n_slaughter_na = sum(is.na(slaughter))
  )

message("E04 — sentinel zeros applied when gateway question == 'no' (animals)")
print(animal_zeros)
# 🚩 FLAG [EXCLUSION]: systematic pattern? High proportion of zeros may indicate recall fatigue

# =============================================================================
# EXCLUSION E05: hides[produced == 0] dropped
# Source: clean/animal_products.R — Section 2 (hides)
# Type: structural zero | missing data — FLAG
# =============================================================================

produce_hides_all <- produce |> as.data.frame() |> filter(productid == "skin / hides")

excluded_E05 <- produce_hides_all |> filter(produced == 0 | is.na(produced))
included_E05 <- produce_hides_all |> filter(produced > 0)

profile_E05 <- bind_rows(
  excluded_E05 |> mutate(group = "excluded"),
  included_E05 |> mutate(group = "included")
) |>
  group_by(group) |>
  summarise(n = n(), n_hh = n_distinct(y4_hhid), .groups = "drop")

message("E05 — hides[produced == 0] dropped")
message("  Excluded (produced == 0 or NA): ", nrow(excluded_E05))
message("  Included (produced > 0): ",        nrow(included_E05))
print(profile_E05)
# 🚩 FLAG [EXCLUSION]: confirm all zero-production cases correspond to zero slaughter

# =============================================================================
# EXCLUSION E06: non-ruminant livestock categories dropped from milk section
# Source: clean/milk.R — Section 1
# Type: structural zero (non-ruminants do not produce milk in this context)
# =============================================================================

# Load milk raw section directly (raw object not available in this script)
milk_raw_path <- here::here("data", "raw", "lsms", "lf_sec_06.dta")
if (file.exists(milk_raw_path)) {
  lf_sec_06_raw <- haven::read_dta(milk_raw_path)
  lf_sec_06_cats <- lf_sec_06_raw |>
    clean_up() |>
    distinct(lvstckcat)

  excluded_E06_cats <- lf_sec_06_cats |>
    filter(!(lvstckcat %in% c("large ruminants", "small ruminants")))

  included_E06_cats <- lf_sec_06_cats |>
    filter(lvstckcat %in% c("large ruminants", "small ruminants"))

  message("E06 — non-ruminant categories dropped from milk section")
  message("  Dropped categories: ", paste(excluded_E06_cats$lvstckcat, collapse = ", "))
  message("  Retained categories: ", paste(included_E06_cats$lvstckcat, collapse = ", "))
} else {
  # lf_sec_06.dta not available — report from clean/milk.rds if present
  milk_clean_path <- here::here("data", "processed", "01", "clean", "milk.rds")
  if (file.exists(milk_clean_path)) {
    milk_clean <- zap_all(readRDS(milk_clean_path))
    message("E06 — retained categories in cleaned milk data: ",
            paste(unique(milk_clean$lvstckcat), collapse = ", "))
  } else {
    message("E06 — lf_sec_06.dta and milk.rds not available; skipping category profile")
  }
  excluded_E06_cats <- data.frame(lvstckcat = character(0))
}
# 🚩 FLAG [EXCLUSION]: confirm no milkable animals coded under dropped categories

# =============================================================================
# EXCLUSION E07: milk exclusion rules (physiological plausibility thresholds)
# Source: clean/milk.R — Section 2, excl_milk derivation
# Type: unclear — FLAG (thresholds not codebook-specified)
# =============================================================================

excluded_E07 <- excl_milk |> filter(!is.na(excl))
included_E07 <- excl_milk |> filter(is.na(excl))

profile_E07 <- excluded_E07 |>
  group_by(excl) |>
  summarise(n = n(), n_hh = n_distinct(y4_hhid), .groups = "drop") |>
  arrange(desc(n))

message("E07 — milk exclusion rules applied")
message("  Total excluded records: ", nrow(excluded_E07))
message("  Total included records: ", nrow(included_E07))
print(profile_E07)
# 🚩 FLAG [EXCLUSION]: profile sensitivity to thresholds (1.3 vs 1.5 for excessive milk use)

# =============================================================================
# EXCLUSION E08: zeros applied where sale/storage/loss gateway == "no" (destinations)
# Source: clean/destinations.R — Section 1, upData() block
# Type: structural zero | missing data — FLAG
# =============================================================================

dest_zeros <- crop_disp |>
  as.data.frame() |>
  summarise(
    n_total       = n(),
    n_sold_zero   = sum(sold    == 0, na.rm = TRUE),
    n_stored_zero = sum(stored  == 0, na.rm = TRUE),
    n_losses_zero = sum(losses  == 0, na.rm = TRUE),
    n_sold_na     = sum(is.na(sold)),
    n_stored_na   = sum(is.na(stored)),
    n_losses_na   = sum(is.na(losses))
  )

message("E08 — sentinel zeros applied where gateway == 'no' (destinations)")
print(dest_zeros)
# 🚩 FLAG [EXCLUSION]: profile proportion of zeros per crop type

# =============================================================================
# EXCLUSION E09: ±30% tolerance on disposition vs harvest (crops)
# Source: clean/destinations.R — Section 3, excl_crops derivation
# Type: unclear — FLAG (threshold chosen pragmatically, not codebook-derived)
# =============================================================================

excluded_E09 <- excl_crops |> filter(!is.na(excl))
included_E09 <- excl_crops |> filter(is.na(excl))

profile_E09 <- excluded_E09 |>
  group_by(excl) |>
  summarise(n = n(), n_hh = n_distinct(y4_hhid), .groups = "drop") |>
  arrange(desc(n))

message("E09 — ±30% tolerance on disposition vs harvest (crops + trees)")
message("  Crops excluded: ",  nrow(excluded_E09))
message("  Crops included: ",  nrow(included_E09))
print(profile_E09)

excl_trees_flag <- excl_trees |> filter(!is.na(excl))
message("  Trees excluded: ",  nrow(excl_trees_flag))
# 🚩 FLAG [EXCLUSION]: profile sensitivity to threshold (20%, 30%, 40%)

# =============================================================================
# EXCLUSION E10: "crop produces no residue" records dropped
# Source: clean/destinations.R — Section 4 (residue estimation)
# Type: unclear — FLAG
# =============================================================================

# Note: double space in filter string — "crop produces no  residue"
# Load from cleaned residue output (raw DTA not available in this script)
excl_E10_from_residue <- mass_residue |>
  as.data.frame() |>
  filter(!is.na(cropid))

# Profile from crop_disp.rds — residue_use column retained in clean/destinations.R
crop_disp_residue_use <- crop_disp |>
  as.data.frame() |>
  filter(!is.na(residue_use))

excluded_E10 <- crop_disp_residue_use |>
  filter(residue_use == "crop produces no  residue")  # note: double space

included_E10 <- crop_disp_residue_use |>
  filter(residue_use != "crop produces no  residue")

message("E10 — 'crop produces no residue' records dropped from residue estimation")
message("  Excluded records (residue_use == 'no residue'): ", nrow(excluded_E10))
message("  Included records: ", nrow(included_E10))
message("  Excluded households: ", n_distinct(excluded_E10$y4_hhid))
# 🚩 FLAG [EXCLUSION]: confirm double-space matches raw data; check codebook ag_sec_5a q33

# =============================================================================
# STAGE 3 STUBS — run after 04_build_households.R is available
# =============================================================================

if (!is.null(households)) {

  # --- E_crops_no_dest: crops with no matching destination record ---
  pc_by_crop <- pc |>
    as.data.frame() |>
    group_by(y4_hhid, cropid) |>
    summarise(harvest_kg = sum(total_harvest, na.rm = TRUE), .groups = "drop")

  cd_by_crop <- crop_disp |>
    as.data.frame() |>
    group_by(y4_hhid, cropid) |>
    summarise(dest_sold_kg = sum(sold, na.rm = TRUE), .groups = "drop")

  crops_no_dest <- pc_by_crop |>
    dplyr::anti_join(cd_by_crop, by = c("y4_hhid", "cropid"))

  message("E_crops_no_dest: n = ", nrow(crops_no_dest))
  print(dplyr::count(crops_no_dest, cropid, sort = TRUE))
  summary(crops_no_dest$harvest_kg)

  # --- E_dest_no_crops: destination records with no matching crop ---
  dest_no_crops <- cd_by_crop |>
    dplyr::anti_join(pc_by_crop, by = c("y4_hhid", "cropid"))

  message("E_dest_no_crops: n = ", nrow(dest_no_crops))
  print(dplyr::count(dest_no_crops, cropid, sort = TRUE))

  # --- E_structural_zero_guard: households where guard changed a value ---
  if ("n_cattle" %in% names(households) && "milk_total_kg" %in% names(households)) {
    milk_guard <- households |>
      dplyr::filter(!is.na(n_cattle) & n_cattle > 0 & is.na(milk_total_kg))
    message("E_structural_zero_guard — milk: ", nrow(milk_guard),
            " households with cattle but NA milk yield")
  }

  if ("n_poultry" %in% names(households) && "egg_produced_kg" %in% names(households)) {
    egg_guard <- households |>
      dplyr::filter(!is.na(n_poultry) & n_poultry > 0 & is.na(egg_produced_kg))
    message("E_structural_zero_guard — eggs: ", nrow(egg_guard),
            " households with poultry but NA egg production")
  }

  if ("crop_n_crops" %in% names(households)) {
    harvest_guard <- households |>
      dplyr::filter(is.na(crop_n_crops))
    message("E_structural_zero_guard — harvest: ", nrow(harvest_guard),
            " households not in crops roster (harvest set to 0)")
  }

} else {
  message("05_exclusions_audit.R: Stage 3 stubs skipped — households.rds not available")
  message("  Run 04_build_households.R first, then re-run this script")
}

# =============================================================================
# EXCLUSION SUMMARY TABLE
# =============================================================================

exclusion_summary <- tribble(
  ~id,                  ~description,                                               ~n_excluded,           ~type,
  "E01",                "harvest values zeroed when harvested == 'no'",             nrow(excluded_E01),    "structural zero | missing data",
  "E02",                "area_planted is NA — replaced with area_harvested_new",    nrow(excluded_E02),    "missing data",
  "E03",                "ag3b_01b == 2 filter on short-season plots",               excluded_E03_count,    "structural (double-count guard)",
  "E04",                "sentinel 0 applied (animal gateway == 'no')",              NA_integer_,           "structural zero | missing data",
  "E05",                "hides[produced == 0] dropped",                             nrow(excluded_E05),    "structural zero | missing data",
  "E06",                "non-ruminant categories dropped from milk",                nrow(excluded_E06_cats),"structural zero",
  "E07",                "milk physiological plausibility exclusions",               nrow(excluded_E07),    "implausible value",
  "E08",                "destination gateway zeros (sale/storage/loss == 'no')",    NA_integer_,           "structural zero | missing data",
  "E09",                "±30% disposition vs harvest tolerance (crops)",            nrow(excluded_E09),    "assumption — threshold not codebook-derived",
  "E10",                "'crop produces no residue' dropped from residue section",  nrow(excluded_E10),    "unclear — confirm codebook"
)

message("\n05_exclusions_audit.R — EXCLUSION SUMMARY")
print(exclusion_summary)

saveRDS(exclusion_summary,
        here::here("data", "processed", "01", "exclusions_summary.rds"),
        compress = TRUE)

message("05_exclusions_audit.R: exclusions_summary.rds saved.")
# 🚩 FLAG [BACKLOG]: systematic exclusion patterns not yet tested — see backlog.md B01
