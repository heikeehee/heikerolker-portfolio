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
