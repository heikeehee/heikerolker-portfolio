# =============================================================================
# 06_mfa_input.R
# PURPOSE: Prepare household-level input matrix for Multiple Factor Analysis (MFA)
# INPUT:   data/processed/households.rds
#          data/processed/clean/mass_crops.rds      (flow allocation, crops)
#          data/processed/clean/mass_trees.rds      (flow allocation, trees)
#          data/processed/clean/mass_milk_final.rds (milk, kg after conversion)
#          data/processed/clean/mass_eggs.rds       (egg mass balance)
#          data/processed/clean/mass_residue.rds    (crop residue flows)
#          data/processed/impute/mass_animals.rds   (slaughter mass balance)
#          data/processed/impute/mass_hides.rds     (hides mass balance)
# OUTPUT:  data/processed/mfa_input.rds — one row per household, analysis-ready
#
# THIS SCRIPT: analytical method requirements only — not data quality
# Transformations here are driven by MFA requirements, not data problems
# Data quality issues belong in clean/ and impute/
# =============================================================================
#
# SOURCE LOGIC FROM:
#   archive/05_Destinations.Rmd — flow allocation already done in clean/destinations.R;
#                                  this script adds mass-balance uncertainty measures
#   archive/06a_Residue.Rmd    — residue already in mass_residue.rds; collapsed here
#   archive/06_Summary.Rmd     — mass-balance variables for MFA (uncertain, missing,
#                                  unallocated pattern for crops, milk, eggs, animals)
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# SECTION 1: LOAD INPUTS
# All flow allocation and cleaning already done in clean/ and impute/ scripts.
# =============================================================================

households   <- readRDS(here::here("data", "processed", "households.rds"))

# Crop & tree flow allocation (per hh × crop; smd already computed in destinations.R)
mass_crops   <- setDT(readRDS(here::here("data", "processed", "clean", "mass_crops.rds")))
mass_trees   <- setDT(readRDS(here::here("data", "processed", "clean", "mass_trees.rds")))

# Milk — all quantities in litres EXCEPT _kg columns added in clean/milk.R
mass_milk    <- setDT(readRDS(here::here("data", "processed", "clean", "mass_milk_final.rds")))

# Eggs
mass_eggs    <- setDT(readRDS(here::here("data", "processed", "clean", "mass_eggs.rds")))

# Residue estimates (DM, from clean/destinations.R)
mass_residue <- setDT(readRDS(here::here("data", "processed", "clean", "mass_residue.rds")))

# Slaughter mass balance (imputed carcass breakdown: meat, offal, hides, inedible, feed)
mass_animals <- setDT(readRDS(here::here("data", "processed", "impute", "mass_animals.rds")))

# Hides — produced and sold from clean/animal_products.R
mass_hides   <- setDT(readRDS(here::here("data", "processed", "clean", "mass_hides.rds")))

# =============================================================================
# SECTION 2: MASS BALANCE — CROPS
# Source logic: archive/06_Summary.Rmd (Crops for MFA)
# mass_crops already has: harvest, sold, stored, losses, consumed,
#                         seed, payment, gifts, feed, residue, smd
# ADD: uncertain, missing, unallocated (not in mass_crops.rds from destinations.R)
# =============================================================================

# 🚩 FLAG [ASSUMPTION]: smd for crops = sold + stored + losses + consumed + payment + gifts + feed
# residue (quantity residue sold) is excluded from smd — treated as external output,
# not part of internal harvest disposition. Confirm interpretation against thesis.
crops_mb <- mass_crops[, `:=`(
  uncertain   = harvest - smd,
  missing     = fifelse(harvest - smd < 0, (harvest - smd) * -1, 0),   # disposition > harvest
  unallocated = fifelse(harvest - smd > 0, harvest - smd, 0)            # disposition < harvest
)]

# Collapse to household level
# 🚩 FLAG [ASSUMPTION]: crops collapsed across all crop types and seasons by sum.
# Crop-type disaggregation is retained in mass_crops.rds if needed for sensitivity analysis.
crops_hh <- crops_mb[,
  .(harvest        = sm(harvest),
    sold           = sm(sold),
    consumed       = sm(consumed),
    stored         = sm(stored),
    seed           = sm(seed),
    payment        = sm(payment),
    gifts          = sm(gifts),
    feed_crops     = sm(feed),
    losses_crops   = sm(losses),
    smd_crops      = sm(smd),
    missing_crops  = sm(missing),
    unalloc_crops  = sm(unallocated)),
  by = .(y4_hhid)
]

# =============================================================================
# SECTION 3: MASS BALANCE — TREES
# Same pattern as crops.
# =============================================================================

trees_mb <- mass_trees[, `:=`(
  uncertain   = harvest - smd,
  missing     = fifelse(harvest - smd < 0, (harvest - smd) * -1, 0),
  unallocated = fifelse(harvest - smd > 0, harvest - smd, 0)
)]

trees_hh <- trees_mb[,
  .(harvest_trees       = sm(harvest),
    sold_trees          = sm(sold),
    consumed_trees      = sm(consumed),
    stored_trees        = sm(stored),
    losses_trees        = sm(losses),
    smd_trees           = sm(smd),
    missing_trees       = sm(missing),
    unalloc_trees       = sm(unallocated)),
  by = .(y4_hhid)
]

# =============================================================================
# SECTION 4: MASS BALANCE — MILK
# Source logic: archive/06_Summary.Rmd (Milk for MFA)
# All quantity columns here use the _kg columns from clean/milk.R (factor 1.03).
# 🚩 FLAG [UNIT]: milk_kg, consumed_kg, sold_kg, processed_new_kg are in kg.
# The original litre columns (milk, consumed, sold, processed) are NOT used here.
# =============================================================================

# 🚩 FLAG [ASSUMPTION]: processed milk sold (psold_kg) is treated as a separate account
# from raw milk sold (sold_kg). If the LSMS survey double-counts these, smd_milk is inflated.
# Check codebook: lf06_08 (quantity sold raw) vs lf06_10 (processed sold) — are they additive?
# NOTE: smd_milk uses processed_new_kg (corrected processed value) not psold_kg.
# psold_kg is tracked separately in the household summary for reference only.
milk_mb <- mass_milk[, `:=`(
  smd_milk   = consumed_kg + sold_kg + processed_new_kg,
  uncertain_milk = milk_kg - (consumed_kg + sold_kg + processed_new_kg),
  missing_milk   = fifelse(milk_kg - (consumed_kg + sold_kg + processed_new_kg) < 0,
                           (milk_kg - (consumed_kg + sold_kg + processed_new_kg)) * -1, 0),
  unalloc_milk   = fifelse(milk_kg - (consumed_kg + sold_kg + processed_new_kg) > 0,
                           milk_kg - (consumed_kg + sold_kg + processed_new_kg), 0)
)]

milk_hh <- milk_mb[,
  .(produced_milk   = sm(milk_kg),
    sold_milk       = sm(sold_kg),
    consumed_milk   = sm(consumed_kg),
    processed_milk  = sm(processed_new_kg),
    psold_milk      = sm(psold_kg),
    smd_milk        = sm(smd_milk),
    missing_milk    = sm(missing_milk),
    unalloc_milk    = sm(unalloc_milk)),
  by = .(y4_hhid)
]

# =============================================================================
# SECTION 5: MASS BALANCE — EGGS
# Source logic: archive/06_Summary.Rmd (Eggs for MFA)
# =============================================================================

# Note: mass_eggs is already in kg (eggs are reported in numbers × weight factor in clean/animal_products.R)
eggs_mb <- mass_eggs[, `:=`(
  smd_eggs     = sold + consumed,
  uncertain_eg = produced - (sold + consumed),
  missing_eg   = fifelse(produced - (sold + consumed) < 0, (produced - (sold + consumed)) * -1, 0),
  unalloc_eg   = fifelse(produced - (sold + consumed) > 0, produced - (sold + consumed), 0)
)]

eggs_hh <- eggs_mb[,
  .(produced_eggs   = sm(produced),
    sold_eggs       = sm(sold),
    consumed_eggs   = sm(consumed),
    feed_eggs       = sm(feed),
    grazed_eggs     = sm(grazed),
    smd_eggs        = sm(smd_eggs),
    missing_eggs    = sm(missing_eg),
    unalloc_eggs    = sm(unalloc_eg)),
  by = .(y4_hhid)
]

# =============================================================================
# SECTION 6: MASS BALANCE — SLAUGHTER ANIMALS
# Source logic: archive/06_Summary.Rmd (Animals for MFA)
# mass_animals from impute/animals.R has: total_weight, sold_weight, cons_weight,
#   meat, offal, hides, inedible, need, feed, grazed, ew
# =============================================================================

# 🚩 FLAG [ASSUMPTION]: uncertain = total_weight - sold_weight - meat - offal - hides - inedible
# Any difference reflects incomplete breakdown coverage (not waste).
# This is the same approach as archive/06_Summary.Rmd.
animals_mb <- mass_animals[, `:=`(
  consumed_animals = meat + offal,
  uncertain_an     = total_weight - sold_weight - meat - offal - hides - inedible,
  missing_an       = fifelse(
    total_weight - sold_weight - meat - offal - hides - inedible < 0,
    (total_weight - sold_weight - meat - offal - hides - inedible) * -1, 0),
  unalloc_an       = fifelse(
    total_weight - sold_weight - meat - offal - hides - inedible > 0,
    total_weight - sold_weight - meat - offal - hides - inedible, 0)
)]

animals_hh <- animals_mb[,
  .(slaughter_weight   = sm(total_weight),
    sold_animals       = sm(sold_weight),
    consumed_animals   = sm(consumed_animals),
    meat               = sm(meat),
    offal              = sm(offal),
    hides_an           = sm(hides),
    inedible           = sm(inedible),
    feed_animals_kgDM  = sm(feed),
    grazed_kgDM        = sm(grazed),
    missing_animals    = sm(missing_an),
    unalloc_animals    = sm(unalloc_an)),
  by = .(y4_hhid)
]

# =============================================================================
# SECTION 7: RESIDUE COLLAPSE
# Source logic: archive/06a_Residue.Rmd + archive/06_Summary.Rmd
# mass_residue already has DM estimates (clean/destinations.R Section 4).
# =============================================================================

residue_hh <- mass_residue[,
  .(residue_DM_total  = sm(Residues_DM),
    residue_wet_total = sm(Residues_wet),
    grazing_res_total = sm(grazing_res)),
  by = .(y4_hhid)
]

# =============================================================================
# SECTION 8: BUILD MFA INPUT MATRIX
# One row per household. Merge all household-level summaries onto households spine.
# =============================================================================

mfa_input <- as.data.frame(households) |>
  select(y4_hhid) |>
  left_join(as.data.frame(crops_hh),    by = "y4_hhid") |>
  left_join(as.data.frame(trees_hh),    by = "y4_hhid") |>
  left_join(as.data.frame(milk_hh),     by = "y4_hhid") |>
  left_join(as.data.frame(eggs_hh),     by = "y4_hhid") |>
  left_join(as.data.frame(animals_hh),  by = "y4_hhid") |>
  left_join(as.data.frame(residue_hh),  by = "y4_hhid") |>
  mutate(across(where(is.numeric), ~ replace_na(., 0)))

# =============================================================================
# SECTION 9: VARIABLE CONSTRUCTION FOR MFA
# Ratios, log transforms, and composite scores
# =============================================================================

mfa_input <- mfa_input |>
  mutate(
    # Harvest total (crops + trees combined)
    harvest_total = harvest + harvest_trees,

    # Share of harvest sold (market orientation)
    # 🚩 FLAG [ASSUMPTION]: sold / harvest used as market integration proxy for crops.
    # Denominator = harvest (crops only, not trees); if harvest == 0, share = NaN → NA.
    share_sold     = fifelse(harvest > 0, sold / harvest, NA_real_),
    share_consumed = fifelse(harvest > 0, consumed / harvest, NA_real_),
    share_stored   = fifelse(harvest > 0, stored / harvest, NA_real_),

    # Log transforms for skewed quantities
    # 🚩 FLAG [ASSUMPTION]: log(x + 1) used throughout to handle zeros.
    # Alternative: log(x) with zero-floor imputation — flag for sensitivity in 08_uncertainty.R.
    # log1p(x) = log(x + 1)
    log_harvest        = log1p(harvest),
    log_harvest_trees  = log1p(harvest_trees),
    log_harvest_total  = log1p(harvest_total),
    log_produced_milk  = log1p(produced_milk),
    log_produced_eggs  = log1p(produced_eggs),
    log_slaughter      = log1p(slaughter_weight),

    # Mass-balance uncertainty ratios
    # 🚩 FLAG [ASSUMPTION]: missing_crops / harvest = fraction of harvest unaccounted for.
    # High values = large discrepancy between production and recorded dispositions.
    unc_ratio_crops = fifelse(harvest > 0, missing_crops / harvest, NA_real_),
    unc_ratio_milk  = fifelse(produced_milk > 0, missing_milk / produced_milk, NA_real_),

    # Treat NaN (0/0) as NA
    across(where(is.numeric), ~ ifelse(is.nan(.), NA_real_, .))
  )

# =============================================================================
# SECTION 10: VARIABLE SELECTION FOR MFA
# Exclude variables that are:
#   (a) derived aggregates collinear with selected variables
#   (b) mass-balance residuals (uncertain, missing, unallocated) — diagnostic only
#   (c) very low variance (structural zeros for most households)
# =============================================================================

# 🚩 FLAG [ASSUMPTION]: Variables excluded from MFA input matrix:
#   - smd_crops, smd_trees, smd_milk, smd_eggs: collinear with sum of disposition cols
#   - missing_*, unalloc_*: diagnostic mass-balance residuals, not independent variables
#   - residue_wet_total: collinear with residue_DM_total (DM = wet × Dry_matter ratio)
#   - inedible: near-structural zero; low variance across households
#   - harvest (absolute): log_harvest preferred for skewed distribution
#   - produced_milk (absolute): log_produced_milk preferred
#   - produced_eggs (absolute): log_produced_eggs preferred
#   - slaughter_weight (absolute): log_slaughter preferred
#   - payment: collinear with gifts (both represent informal transfers)
# Review this exclusion list against MFA variance explained and variable contributions
# before publishing — if first dimensions dominated by one block, revise.

mfa_input_mfa <- mfa_input |>
  select(
    y4_hhid,
    # --- Block 1: Crop production volumes ---
    log_harvest, log_harvest_trees, log_harvest_total,
    # --- Block 2: Crop flow allocation ---
    share_sold, share_consumed, share_stored,
    # --- Block 3: Crop mass-balance quality ---
    unc_ratio_crops,
    # --- Block 4: Milk ---
    log_produced_milk, sold_milk, consumed_milk, unc_ratio_milk,
    # --- Block 5: Eggs ---
    log_produced_eggs, sold_eggs, consumed_eggs,
    # --- Block 6: Slaughter products ---
    log_slaughter, sold_animals, consumed_animals, meat, offal,
    # --- Block 7: Feed and residue ---
    residue_DM_total, grazing_res_total,
    feed_animals_kgDM, grazed_kgDM
  )

# =============================================================================
# SECTION 11: SAVE
# =============================================================================

saveRDS(mfa_input_mfa, here::here("data", "processed", "mfa_input.rds"))
message("MFA input matrix: ", nrow(mfa_input_mfa), " households × ", ncol(mfa_input_mfa), " variables")
