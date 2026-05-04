# =============================================================================
# 05_exclusions_audit.R
# PURPOSE: Profile all households excluded at each pipeline stage
# INPUT:   data/processed/clean/*.rds + households.rds (stage 3 output)
# OUTPUT:  data/processed/exclusions_summary.rds + summary table
# NOTE:    Run AFTER 04_build_households.R
#          This script changes nothing — it only reports.
# =============================================================================

# =============================================================================
# HOW TO USE THIS FILE
# Each exclusion block below corresponds to a filter or zero-replacement in a
# clean/ script. After 04_build_households.R is written, add anti-join code
# to compare excluded vs included households on: region, land size, wealth index.
# =============================================================================

# --- EXCLUSION E01: harvest values set to 0 when harvested == "no" ---
# Script: clean/crops.R — Section 2 (crops), upData() block
# Type: structural zero | missing data — FLAG
# Filter: harvest_remain = 0, area_harvested = 0, quant_harvest = 0 when harvested == "no"
# Action needed: compare excluded vs included on key vars (region, land size, wealth)
# Placeholder — complete after 04_build_households.R is written

# --- EXCLUSION E02: 2 records where area_planted is NA ---
# Script: clean/crops.R — crop-plot merge section
# Type: missing data
# Filter: area_planted_new replaced with area_harvested_new for ~2 records
# Action needed: identify which y4_hhid/cropid these are; confirm replacement is valid
# Placeholder — complete after 04_build_households.R is written

# --- EXCLUSION E03: ag3b_01b == 2 filter on short-season plots ---
# Script: clean/crops.R — Section 4 (plot details), short-season filter
# Type: unclear — FLAG (confirm codebook meaning before stage 3)
# Filter: filter(ag3b_01b == 2) — retains only plots where ag3b_01b equals 2
# Action needed: confirm codebook meaning of ag3b_01b == 2; count excluded plots;
#   compare excluded vs included on crop type and yield
# Placeholder — complete after 04_build_households.R is written

# --- EXCLUSION E04: sentinel 0 applied when gateway question == "no" (animals) ---
# Script: clean/animals.R — Section 1 (ownership/slaughter), upData() block
# Type: structural zero | missing data — FLAG
# Filter: bought, gift, gifted, disease, theft, injury, sold, slaughter set to 0
#   when corresponding gateway question == "no"
# Action needed: profile proportion of zeros vs NAs per variable; flag households
#   with implausibly high proportion of "no" responses (possible recall fatigue)
# Placeholder — complete after 04_build_households.R is written

# --- EXCLUSION E05: hides[produced == 0] dropped ---
# Script: clean/animal_products.R — Section 2 (hides)
# Type: structural zero | missing data — FLAG
# Filter: hides <- hides[produced > 0]
# Action needed: count dropped records; confirm all zero-production cases correspond
#   to households with zero slaughter (structural) vs households with slaughter but no
#   recorded hides (missing data)
# Placeholder — complete after 04_build_households.R is written

# --- EXCLUSION E06: non-ruminant livestock categories dropped from milk section ---
# Script: clean/milk.R — Section 1 (load and rename)
# Type: structural zero (non-ruminants do not produce milk in this context)
# Filter: milk <- milk[lvstckcat == "large ruminants" | lvstckcat == "small ruminants"]
# Action needed: confirm no milkable animals (e.g. camels) are coded under other
#   livestock categories in the NPS4 codebook; check unique(lvstckcat) in lf_sec_06
# Placeholder — complete after 04_build_households.R is written

# --- EXCLUSION E07: milk exclusion rules (physiological plausibility thresholds) ---
# Script: clean/milk.R — Section 2 (reconciliation), excl_milk derivation
# Type: unclear — FLAG (thresholds not codebook-specified)
# Filter: Households excluded if:
#   - period > 310 & milked == 1 → "Implausible"
#   - smd1 > 7 & milked == 1 → "Implausible"
#   - mean * 1.2 < consumed / sold / processed → "Data inconsistent"
#   - smd1 > mean * 1.5 → "Excessive milk use"
#   - smd1 <= mean * 0.5 → "Milk unaccounted"
# Action needed: compare excluded vs included on: animal type, region, milked count;
#   profile sensitivity to threshold values (e.g. 1.3 vs 1.5 for excessive milk use)
# Placeholder — complete after 04_build_households.R is written

# --- EXCLUSION E08: zeros applied where sale/storage/loss gateway == "no" (destinations) ---
# Script: clean/destinations.R — Section 1 (crop disposition), upData() block
# Type: structural zero | missing data — FLAG
# Filter: sold, soldb1, soldb2 = 0 when sale == "no";
#         stored = 0 when storage == "no";
#         losses = 0 when lost == "no"
# Action needed: profile proportion of zeros per variable and crop; flag households
#   with implausibly zero disposition across all channels
# Placeholder — complete after 04_build_households.R is written

# --- EXCLUSION E09: ±30% tolerance on disposition vs harvest (crops) ---
# Script: clean/destinations.R — Section 3 (merge), excl_crops derivation
# Type: unclear — FLAG (threshold not codebook-derived, chosen pragmatically)
# Filter: excl = "Harvest insufficient" if smd > harvest * 1.3
#         excl = "Harvest unaccounted"  if smd < harvest * 0.7
# Action needed: profile sensitivity of this threshold (20%, 30%, 40%);
#   compare excluded households on region and crop type;
#   examine whether excluded crops are concentrated in specific crop types
# Placeholder — complete after 04_build_households.R is written

# --- EXCLUSION E10: crops reporting "crop produces no residue" dropped ---
# Script: clean/destinations.R — Section 4 (residue estimation)
# Type: unclear — FLAG (confirm this is a survey category not a data-entry placeholder)
# Filter: res_hh[residue_use != "crop produces no  residue"]
#   Note: double space in the filter string — verify this matches the raw data value exactly
# Action needed: count dropped crop-household records; confirm the response category
#   is genuinely a survey option (LSMS codebook ag_sec_5a question 33);
#   if a data-entry artefact, these records should be retained with residue = NA
# Placeholder — complete after 04_build_households.R is written

# =============================================================================
# EXCLUSIONS FROM 04_build_households.R (stage 3)
# Run the code stubs below after households.rds exists
# =============================================================================

# --- EXCLUSION E_crops_no_dest: crops with no matching destination record ---
# Source: 04_build_households.R — Section 4 (C05 anti-join)
# Type: misalignment — known finding (see FLAGS_REVIEW.md, methods appendix)
# Note: these are crop–household records in pc.rds with no corresponding entry
#       in crop_disp.rds. May reflect genuine non-disposal crops, recall gaps, or
#       crops harvested but not yet disposed of at time of survey.
# Action needed: profile by crop type, region, harvest quantity; compare with
#       dest_no_crops to assess directionality of mismatch.
# Stub — run after households.rds is available:
#
# households <- readRDS(here::here("data", "processed", "households.rds"))
# pc         <- readRDS(here::here("data", "processed", "clean", "pc.rds"))
# crop_disp  <- readRDS(here::here("data", "processed", "clean", "crop_disp.rds"))
#
# pc_by_crop <- pc |>
#   as.data.frame() |>
#   dplyr::group_by(y4_hhid, cropid) |>
#   dplyr::summarise(harvest_kg = sum(total_harvest, na.rm = TRUE), .groups = "drop")
#
# cd_by_crop <- crop_disp |>
#   as.data.frame() |>
#   dplyr::group_by(y4_hhid, cropid) |>
#   dplyr::summarise(dest_sold_kg = sum(sold, na.rm = TRUE), .groups = "drop")
#
# crops_no_dest <- pc_by_crop |>
#   dplyr::anti_join(cd_by_crop, by = c("y4_hhid", "cropid"))
#
# message("E_crops_no_dest: n = ", nrow(crops_no_dest))
# # Profile: crop type distribution
# print(dplyr::count(crops_no_dest, cropid, sort = TRUE))
# # Profile: harvest quantity in unmatched records
# summary(crops_no_dest$harvest_kg)

# --- EXCLUSION E_dest_no_crops: destination records with no matching crop ---
# Source: 04_build_households.R — Section 4 (C06 anti-join)
# Type: misalignment — known finding (see FLAGS_REVIEW.md, methods appendix)
# Note: these are entries in crop_disp.rds with no corresponding production
#       record in pc.rds. May reflect crops planted in a season not covered by pc,
#       or data entry errors in cropid coding.
# Action needed: profile by crop type and disposition channel (sold, consumed, stored);
#       compare with crops_no_dest; check if cropid coding differs across sections.
# Stub — run after households.rds is available:
#
# dest_no_crops <- cd_by_crop |>
#   dplyr::anti_join(pc_by_crop, by = c("y4_hhid", "cropid"))
#
# message("E_dest_no_crops: n = ", nrow(dest_no_crops))
# # Profile: crop type distribution
# print(dplyr::count(dest_no_crops, cropid, sort = TRUE))
# # Profile: disposition quantities in unmatched records
# summary(dest_no_crops$dest_sold_kg)

# --- EXCLUSION E_structural_zero_guard: households where guard changed a value ---
# Source: 04_build_households.R — Section 6 (structural zero guards)
# Type: structural zero (confirmed by roster) or potential data issue
# Note: the case_when guards in Section 6 may set values to 0 (confirmed structural)
#       or to NA (ambiguous — roster says "yes" but value is missing).
#       Both types need profiling before exclusion or imputation decisions.
# Action needed: count households affected per variable; cross-tabulate with
#       region and asset index to check for systematic patterns.
# Stub — run after households.rds is available:
#
# households <- readRDS(here::here("data", "processed", "households.rds"))
#
# # Milk: households with cattle but NA milk yield (guard set to NA_real_)
# milk_guard <- households |>
#   dplyr::filter(!is.na(n_cattle) & n_cattle > 0 & is.na(milk_total_kg))
# message("E_structural_zero_guard — milk: ", nrow(milk_guard),
#         " households with cattle but NA milk yield")
#
# # Eggs: households with poultry but NA egg production (guard set to NA_real_)
# egg_guard <- households |>
#   dplyr::filter(!is.na(n_poultry) & n_poultry > 0 & is.na(egg_produced_kg))
# message("E_structural_zero_guard — eggs: ", nrow(egg_guard),
#         " households with poultry but NA egg production")
#
# # Harvest: households not in crops roster (guard set to 0)
# harvest_guard <- households |>
#   dplyr::filter(is.na(crop_n_crops))
# message("E_structural_zero_guard — harvest: ", nrow(harvest_guard),
#         " households not in crops roster (harvest set to 0)")
