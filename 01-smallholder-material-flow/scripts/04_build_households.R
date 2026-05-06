# =============================================================================
# 04_build_households.R
# PURPOSE: Merge all section outputs into one row per household
# INPUT:   data/processed/clean/*.rds + data/processed/imputed/*.rds
# OUTPUT:  data/processed/households.rds
#
# JOIN ORDER:
#   1. Household roster (y4_hhid spine)
#   2. Crops (aggregate plot/crop rows → household level)
#   3. Trees / ag_produce (aggregate → household level)
#   4. Animals (aggregate animal-type rows → household level)
#   5. Animal products (join after animals — depends on animals_fin)
#   6. Milk (join after animals — depends on feed_short)
#   7. Recall consumption
#   8. Destinations (join after crops — known misalignment, profile below)
#   9. Imputed values (yield_gap, animals) joined last, flag where they replace observed
#
# KEY: y4_hhid — consistent across sections but NOT unique within sections
# Rule: aggregate to household level before every join
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "01"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# SECTION 1: Load all processed section files
# =============================================================================
zap_all <- function(df) {
  haven::zap_labels(haven::zap_label(as.data.frame(df)))
}

# Clean section outputs
pc              <- zap_all(readRDS(here::here("data", "processed", "01", "clean", "pc.rds")))
pt              <- zap_all(readRDS(here::here("data", "processed", "01", "clean", "pt.rds")))
plots_stats     <- zap_all(readRDS(here::here("data", "processed", "01", "clean", "plots_stats.rds")))
mass_agprod     <- zap_all(readRDS(here::here("data", "processed", "01", "clean", "mass_agprod.rds")))
animals_fin     <- zap_all(readRDS(here::here("data", "processed", "01", "clean", "animals_fin.rds")))
mass_eggs       <- zap_all(readRDS(here::here("data", "processed", "01", "clean", "mass_eggs.rds")))
mass_milk_final <- zap_all(readRDS(here::here("data", "processed", "01", "clean", "mass_milk_final.rds")))
recall          <- zap_all(readRDS(here::here("data", "processed", "01", "clean", "recall.rds")))
crop_disp       <- zap_all(readRDS(here::here("data", "processed", "01", "clean", "crop_disp.rds")))
mass_residue    <- zap_all(readRDS(here::here("data", "processed", "01", "clean", "mass_residue.rds")))
mass_hides      <- zap_all(readRDS(here::here("data", "processed", "01", "clean", "mass_hides.rds")))

# Imputed outputs
yieldgaps    <- zap_all(readRDS(here::here("data", "processed", "01", "impute", "yieldgaps.rds")))
mass_animals <- zap_all(readRDS(here::here("data", "processed", "01", "impute", "mass_animals.rds")))

# =============================================================================
# SECTION 2: Build household spine
# The spine is the union of all y4_hhid values present across all sections.
# A reduce(full_join) ensures no household is silently dropped, even if they
# appear in only one section (recall-only, animals-only, etc.).
# A master household roster is not available separately in the NPS4 pipeline;
# the union approach is the next-best alternative and is conservative.
# =============================================================================
spine_id <- function(df) {
  dplyr::distinct(df, y4_hhid)
}

spine <- purrr::reduce(
  list(
    spine_id(pc),
    spine_id(pt),
    spine_id(animals_fin),
    spine_id(mass_eggs),
    spine_id(mass_milk_final),
    spine_id(recall),
    spine_id(crop_disp),
    spine_id(mass_agprod)
  ),
  function(a, b) dplyr::full_join(a, b, by = "y4_hhid")
)

n_spine <- nrow(spine)
message("Spine built: ", n_spine, " unique households across all sections.")

# =============================================================================
# SECTION 3: Aggregate each section to household level
# BEFORE joining — y4_hhid is not unique within any section
# =============================================================================

# -- 3.1 Plot statistics -------------------------------------------------------
# plots_stats (from clean/crops.R) is already at household level: land, land_gps, nplots
# No aggregation needed — join directly in Section 5.

# -- 3.2 Crops (pc.rds) -------------------------------------------------------
# One row per plot × crop — aggregate to household level.
# Also produce hh × cropid version for misalignment profiling in Section 4.

# Household-level summary
crops_hh <- pc |>
  as.data.frame() |>
  dplyr::group_by(y4_hhid) |>
  dplyr::summarise(
    crop_total_harvest_kg      = sum(total_harvest,     na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    crop_area_planted_ha       = sum(area_planted_new,  na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    crop_n_crops               = dplyr::n_distinct(cropid),
    crop_n_plots               = dplyr::n_distinct(plotnum),
    crop_n_plots_with_mismatch = sum(mismatch, na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    .groups = "drop"
  )

# hh × cropid level — for misalignment anti-join in Section 4 ONLY; not used in final join
pc_by_crop <- pc |>
  as.data.frame() |>
  dplyr::group_by(y4_hhid, cropid) |>
  dplyr::summarise(
    harvest_kg      = sum(total_harvest,    na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    area_planted_ha = sum(area_planted_new, na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    .groups = "drop"
  )

# -- 3.3 Trees (pt.rds) -------------------------------------------------------
# One row per plot × tree crop — aggregate to household level.

trees_hh <- pt |>
  as.data.frame() |>
  dplyr::group_by(y4_hhid) |>
  dplyr::summarise(
    tree_total_harvest_kg = sum(harvest, na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    tree_n_crops          = dplyr::n_distinct(cropid),
    tree_total_ntrees     = sum(ntrees, na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    .groups = "drop"
  )

# -- 3.4 Processed ag products (mass_agprod.rds) ------------------------------
# One row per hh × crop — aggregate to household level.

agprod_hh <- mass_agprod |>
  as.data.frame() |>
  dplyr::group_by(y4_hhid) |>
  dplyr::summarise(
    agprod_produced_kg = sum(produced, na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    agprod_sold_kg     = sum(sold,     na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    agprod_consumed_kg = sum(consumed, na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    .groups = "drop"
  )

# -- 3.5 Animals (animals_fin.rds) -------------------------------------------
# One row per hh × type × lvstckid — aggregate to household level.
# Compute type-specific counts here; these are used for structural zero guards (Section 6).

animals_hh <- animals_fin |>
  as.data.frame() |>
  dplyr::group_by(y4_hhid) |>
  dplyr::summarise(
    n_cattle          = sum(current[type == "large ruminants"], na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    n_small_ruminants = sum(current[type == "small ruminants"], na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    n_pigs            = sum(current[type == "pigs"],            na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    n_poultry         = sum(current[type == "poultry"],         na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    n_total_livestock = sum(current, na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    total_slaughter   = sum(slaughter, na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    total_sl_weight   = sum(sl_weight, na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    owns_cattle          = as.integer(any(type == "large ruminants" & current > 0, na.rm = TRUE)),
    owns_poultry         = as.integer(any(type == "poultry"          & current > 0, na.rm = TRUE)),
    owns_small_ruminants = as.integer(any(type == "small ruminants"  & current > 0, na.rm = TRUE)),
    .groups = "drop"
  )

# -- 3.6 Hides (mass_hides.rds) ----------------------------------------------
# One row per hh × animal type — aggregate to household level.
# C02 dependency note: mass_hides.rds was produced in clean/animal_products.R
# using wa.rds (carcass breakdown) and animals_fin.rds from clean/animals.R.
# The cross-section dependency is resolved here — no re-join needed.

hides_hh <- mass_hides |>
  as.data.frame() |>
  dplyr::group_by(y4_hhid) |>
  dplyr::summarise(
    hides_produced_kg = sum(pprod, na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    hides_sold_kg     = sum(sold2, na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    .groups = "drop"
  )

# -- 3.7 Eggs (mass_eggs.rds) ------------------------------------------------
# One row per hh × poultry type — aggregate to household level.
# C03 dependency note: mass_eggs.rds was produced in clean/animal_products.R
# using animals_fin.rds and feed_short.rds from clean/animals.R.
# The cross-section dependency is resolved here — no re-join needed.

eggs_hh <- mass_eggs |>
  as.data.frame() |>
  dplyr::group_by(y4_hhid) |>
  dplyr::summarise(
    egg_produced_kg = sum(produced, na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    egg_sold_kg     = sum(sold,     na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    egg_feed_kgDM   = sum(feed,     na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    .groups = "drop"
  )

# -- 3.8 Milk (mass_milk_final.rds) ------------------------------------------
# One row per hh × livestock type (large/small ruminants) — aggregate to hh level.
# C04 dependency note: mass_milk_final.rds was produced in clean/milk.R using
# feed_short.rds from clean/animals.R. Cross-section dependency resolved here.
# Unit conversion applied in clean/milk.R (factor 1.03 kg/litre):
# milk → milk_kg; sold → sold_kg; consumed → consumed_kg (all now in kg)
# milk_feed_kgDM uses feed column which is already in kg DM (not converted).

milk_hh <- mass_milk_final |>
  as.data.frame() |>
  dplyr::group_by(y4_hhid) |>
  dplyr::summarise(
    milk_total_kg    = sum(milk_kg,      na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    milk_sold_kg     = sum(sold_kg,      na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    milk_consumed_kg = sum(consumed_kg,  na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    milk_feed_kgDM   = sum(feed,         na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    .groups = "drop"
  )

# -- 3.9 Recall (recall.rds) -------------------------------------------------
# One row per hh × food item — aggregate to household level.
# Filter to items where consumed == "yes" before summing.

recall_hh <- recall |>
  as.data.frame() |>
  dplyr::filter(consumed == "yes") |>
  dplyr::group_by(y4_hhid) |>
  dplyr::summarise(
    recall_n_items       = dplyr::n(),
    recall_consumed_kg   = sum(quantity_kg,   na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    recall_purchases_kg  = sum(purchases_kg,  na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    recall_production_kg = sum(production_kg, na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    recall_gifts_kg      = sum(gifts_kg,      na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    .groups = "drop"
  )

# -- 3.10 Destinations (crop_disp.rds) ---------------------------------------
# One row per hh × crop × season — aggregate to two levels:
#   (a) hh × cropid — for misalignment anti-join in Section 4 ONLY
#   (b) hh level — for final join in Section 5

# (a) hh × cropid — misalignment profiling only
cd_by_crop <- crop_disp |>
  as.data.frame() |>
  dplyr::group_by(y4_hhid, cropid) |>
  dplyr::summarise(
    dest_sold_kg     = sum(sold,     na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    dest_consumed_kg = sum(consumed, na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    dest_stored_kg   = sum(stored,   na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    .groups = "drop"
  )

# (b) hh level — final join
destinations_hh <- crop_disp |>
  as.data.frame() |>
  dplyr::group_by(y4_hhid) |>
  dplyr::summarise(
    dest_sold_kg     = sum(sold,     na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    dest_consumed_kg = sum(consumed, na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    dest_stored_kg   = sum(stored,   na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    dest_seed_kg     = sum(seed,     na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    dest_feed_kg     = sum(feed,     na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    dest_gifts_kg    = sum(gifts,    na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    .groups = "drop"
  )

# -- 3.11 Residue (mass_residue.rds) -----------------------------------------
# One row per hh × crop — aggregate to household level.
# C06 dependency note: mass_residue.rds depends on crop_disp.rds (Section 4 of
# clean/destinations.R runs after Section 3 which used pc.rds). Resolved here —
# residue_hh is joined after destinations_hh in Section 5.

residue_hh <- mass_residue |>
  as.data.frame() |>
  dplyr::group_by(y4_hhid) |>
  dplyr::summarise(
    residue_DM_kg        = sum(Residues_DM,  na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    residue_grazing_DM   = sum(grazing_res,  na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    .groups = "drop"
  )

# -- 3.12 Yield gap imputed (yieldgaps.rds) ----------------------------------
# One row per hh × crop × plot — aggregate to household level.
# 🚩 FLAG [ASSUMPTION]: yg_mean_t_ha averages across crops and plots within
# a household, losing crop-level variation. Consider crop-type-specific gaps for MFA.

yieldgaps_hh <- yieldgaps |>
  as.data.frame() |>
  dplyr::group_by(y4_hhid) |>
  dplyr::summarise(
    yg_mean_t_ha         = mean(YG,          na.rm = TRUE),
    yg_n_crops_matched   = sum(!is.na(YP)),
    .groups = "drop"
  )

# -- 3.13 Animal feed and carcass imputed (mass_animals.rds) -----------------
# One row per hh × type × lvstckid — aggregate to household level.

mass_animals_hh <- mass_animals |>
  as.data.frame() |>
  dplyr::group_by(y4_hhid) |>
  dplyr::summarise(
    animal_meat_kg        = sum(meat,    na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    animal_offal_kg       = sum(offal,   na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    animal_hides_kg       = sum(hides,   na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    animal_feed_need_kgDM = sum(need,    na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    animal_feed_kgDM      = sum(feed,    na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    animal_grazed_kgDM    = sum(grazed,  na.rm = TRUE),
    # 🚩 FLAG [ASSUMPTION]: na.rm = TRUE in sum() treats NA as 0 — confirm these are structural zeros not missing data
    .groups = "drop"
  )

# =============================================================================
# SECTION 4: Resolve cross-section dependencies
# =============================================================================

# C02/C03: animal_products depends on animals_fin and feed_short
# -----------------------------------------------------------------------
# mass_hides.rds and mass_eggs.rds were produced in clean/animal_products.R
# using wa.rds and animals_fin.rds (C02) and animals_fin.rds + feed_short.rds (C03).
# Here we attach the aggregated animals_hh ownership flags to verify structural zeros
# for egg production in Section 6. The flag columns are already in animals_hh
# and will be available after the join in Section 5.
eggs_resolved <- eggs_hh |>
  dplyr::left_join(
    dplyr::select(animals_hh, y4_hhid, n_poultry, owns_poultry),
    by = "y4_hhid"
  )
# eggs_resolved used for documentation; final join uses eggs_hh (Section 5)
# n_poultry / owns_poultry come from animals_hh which is joined to households directly.

# C04: milk depends on feed_short from animals section
# -----------------------------------------------------------------------
# mass_milk_final.rds was produced in clean/milk.R using feed_short.rds from
# clean/animals.R. The feed calculation is already embedded in mass_milk_final.
# Here we attach cattle ownership flags for structural zero guard in Section 6.
milk_resolved <- milk_hh |>
  dplyr::left_join(
    dplyr::select(animals_hh, y4_hhid, n_cattle, owns_cattle),
    by = "y4_hhid"
  )
# milk_resolved used for documentation; final join uses milk_hh (Section 5).
# n_cattle / owns_cattle come from animals_hh which is joined to households directly.

# C05/C06: destinations depends on crops — join here, profile mismatches
# -----------------------------------------------------------------------
# FINDING: crops–destinations misalignment — see 05_exclusions_audit.R and methods appendix

# Anti-join at hh × cropid level: crops with no destination record
crops_no_dest <- pc_by_crop |>
  dplyr::anti_join(cd_by_crop, by = c("y4_hhid", "cropid"))
# 🚩 FLAG [EXCLUSION]: crops_no_dest — n = ? — profile in 05_exclusions_audit.R

# Anti-join at hh × cropid level: destinations with no crop record
dest_no_crops <- cd_by_crop |>
  dplyr::anti_join(pc_by_crop, by = c("y4_hhid", "cropid"))
# 🚩 FLAG [EXCLUSION]: dest_no_crops — n = ? — profile in 05_exclusions_audit.R

message("Crops with no destination record: ", nrow(crops_no_dest))
message("Destinations with no crop record: ", nrow(dest_no_crops))

# =============================================================================
# SECTION 5: Build household-level dataset — left_join from spine outward
# Rule: every join is left_join — no inner joins that silently drop households
# =============================================================================

households <- spine |>

  # Land and plot statistics (already at hh level from clean/crops.R)
  dplyr::left_join(as.data.frame(plots_stats), by = "y4_hhid") |>

  # Crops (aggregated from plot × crop → hh level)
  dplyr::left_join(crops_hh, by = "y4_hhid") |>

  # Trees
  dplyr::left_join(trees_hh, by = "y4_hhid") |>

  # Processed ag products
  dplyr::left_join(agprod_hh, by = "y4_hhid") |>

  # Animals (aggregated from type × lvstckid → hh level)
  # Provides ownership flags (n_cattle, n_poultry, owns_*) used in Section 6 guards
  dplyr::left_join(animals_hh, by = "y4_hhid") |>

  # Animal products — hides
  # C02 resolved: wa.rds + animals_fin incorporated in mass_hides (clean/animal_products.R)
  dplyr::left_join(hides_hh, by = "y4_hhid") |>

  # Animal products — eggs
  # C03 resolved: animals_fin + feed_short incorporated in mass_eggs (clean/animal_products.R)
  dplyr::left_join(eggs_hh, by = "y4_hhid") |>

  # Milk
  # C04 resolved: feed_short incorporated in mass_milk_final (clean/milk.R)
  dplyr::left_join(milk_hh, by = "y4_hhid") |>

  # Recall consumption (7-day food consumption recall)
  dplyr::left_join(recall_hh, by = "y4_hhid") |>

  # Destinations — crop dispositions
  # C05 resolved: misalignment with crops profiled above (Section 4)
  dplyr::left_join(destinations_hh, by = "y4_hhid") |>

  # Crop residue — run after destinations (C06: residue depends on crop_disp.rds)
  dplyr::left_join(residue_hh, by = "y4_hhid") |>

  # Imputed: yield gap (replaces observed yield where GYGA match available)
  dplyr::left_join(yieldgaps_hh, by = "y4_hhid") |>

  # Imputed: animal feed and carcass breakdown
  dplyr::left_join(mass_animals_hh, by = "y4_hhid")

# =============================================================================
# SECTION 6: Structural zero guards
# Rule: only fill 0 if the ownership/planting flag confirms non-participation.
# Guard against silently filling genuine missing data.
# Pattern: case_when(roster_flag confirms absence → 0,
#                    roster_flag confirms presence but value NA → NA_real_,
#                    TRUE → observed value)
# =============================================================================

households <- households |>
  dplyr::mutate(

    # Milk yield: conditioned on cattle (large ruminant) ownership
    milk_total_kg = dplyr::case_when(
      !is.na(n_cattle) & n_cattle == 0             ~ 0,              # structural zero — no cattle
      !is.na(n_cattle) & n_cattle > 0 & is.na(milk_total_kg) ~ NA_real_,  # missing — goes to impute/
      TRUE ~ milk_total_kg
    ),
    # 🚩 FLAG [ASSUMPTION]: households with cattle but NA milk yield treated as missing not zero — confirm

    # Egg production: conditioned on poultry ownership
    egg_produced_kg = dplyr::case_when(
      !is.na(n_poultry) & n_poultry == 0                              ~ 0,
      !is.na(n_poultry) & n_poultry > 0 & is.na(egg_produced_kg)     ~ NA_real_,
      TRUE ~ egg_produced_kg
    ),
    # 🚩 FLAG [ASSUMPTION]: households with poultry but NA egg production treated as missing not zero — confirm

    # Harvest quantities: conditioned on crop planted flag (presence in crops roster)
    # If crop_n_crops is NA, the household was not in pc.rds — treated as non-producer
    crop_total_harvest_kg = dplyr::case_when(
      is.na(crop_n_crops)                                              ~ 0,     # structural zero — not in crops roster
      !is.na(crop_n_crops) & is.na(crop_total_harvest_kg)             ~ NA_real_,
      TRUE ~ crop_total_harvest_kg
    ),
    # 🚩 FLAG [ASSUMPTION]: households absent from crops roster assumed non-producers (structural zero) — confirm

    # Destination quantities: conditioned on harvest > 0
    # If crop_total_harvest_kg == 0, household has no harvest to dispose of
    dest_sold_kg = dplyr::case_when(
      !is.na(crop_total_harvest_kg) & crop_total_harvest_kg == 0      ~ 0,
      !is.na(crop_total_harvest_kg) & crop_total_harvest_kg > 0 & is.na(dest_sold_kg) ~ NA_real_,
      TRUE ~ dest_sold_kg
    )
    # 🚩 FLAG [ASSUMPTION]: households with zero harvest treated as having zero sales — confirm

  )

# =============================================================================
# SECTION 7: Final output
# =============================================================================

saveRDS(households, here::here("data", "processed", "01", "households.rds"))

# Export for Python translation — parquet format
# Required by python/01_load_data.py and downstream Python scripts
arrow::write_parquet(households, here::here("data", "processed", "01", "households.parquet"))
message("Parquet export: households.parquet")

# Diagnostic summary — print to console, do not suppress
message("=== 04_build_households.R complete ===")
message("Households in final dataset: ", nrow(households))
message("Households in spine:         ", n_spine)
message("Households dropped:          ", n_spine - nrow(households))
message("Crops–destinations mismatches: ", nrow(crops_no_dest),
        " crops unmatched, ", nrow(dest_no_crops), " destinations unmatched")
message("Variables with imputed values: yield_gap (yieldgaps_hh), animal feed/carcass (mass_animals_hh)")
