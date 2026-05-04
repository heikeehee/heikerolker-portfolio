# =============================================================================
# impute/animal_products.R
# PURPOSE: Document all assumptions embedded in clean/animal_products.R
#          This script is a documentation registry only — the actual computation
#          code runs in clean/animal_products.R to keep the pipeline sequential.
# INPUT:   (none — documentation only in current form)
# OUTPUT:  (none — see clean/animal_products.R for pipeline output)
# NOTE:    Run AFTER clean/animal_products.R
# =============================================================================

library(here)
library(tidyverse)

# =============================================================================
# ASSUMPTIONS REGISTRY — sourced from clean/animal_products.R
# =============================================================================

# --- ASSUMPTION A12: Hides allocation to animal type (heuristic fcase logic) ---
# Source: unknown — expert judgement / heuristic
# Value: Hides are allocated to large or small ruminants using reported piece counts
#   and slaughter numbers via a cascading fcase() logic:
#   - pieces <= large ruminant slaughter → assign to large ruminants
#   - pieces <= small ruminant slaughter → assign to small ruminants
#   - etc. (see full fcase in clean/animal_products.R, hides section)
# Applied in: clean/animal_products.R — Section 2 (hides), weight and type assignment
# Sensitivity: Heuristic branches are not codebook-derived. Mis-classification of
#   hides between large and small ruminants would affect MFA hide flows. Number of
#   affected households unknown — profile in 05_exclusions_audit.R.
# Action: Review each fcase() branch with a domain expert before stage 3.
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

# --- ASSUMPTION A13: Three households — manual hides split ---
# Source: manual inspection of raw data (data-derived)
# Value: For three households that cannot be algorithmically split between
#   large and small ruminants, weights are assigned manually:
#   - 7294-001: large ruminants = 1.5 kg, small ruminants = 1.5 kg
#   - 8014-001: large ruminants = 0 kg, small ruminants = 5 kg
#   - 4764-001: large ruminants = 1 kg, small ruminants = 1 kg
# Applied in: clean/animal_products.R — Section 2 (hides), manualfix block
# Sensitivity: Single-household impact per case. Flag for re-review if raw data changes.
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

# --- ASSUMPTION A14: Poultry feed fractions (backyard, @MacLeod.2013 p.107) ---
# Source: @MacLeod.2013 (FAO 2013), Table 4, p.107 — SSA backyard poultry
# Value: Feed fractions by feeding practice for poultry:
#   - only feeding:                 feed = 1.0, grazed = 0.0
#   - mainly grazing/scavenging:    feed = 0.4, grazed = 0.6
#   - only grazing/scavenging:      feed = 0.0, grazed = 1.0
#   - mainly feeding, some grazing: feed = 0.6, grazed = 0.4
#   - tethering:                    feed = 0.5, grazed = 0.5
# Applied in: clean/animal_products.R — Section 3 (eggs), chicken feed table
# Note: These same values are used in impute/animals.R. Consolidate into a shared
#   reference file (data/reference/feed_fractions.csv) when pipeline is stable.
# Sensitivity: SSA-level averages. Tanzania-specific backyard poultry feeding may differ.
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

# --- ASSUMPTION A15: Egg laying rate — 45 eggs/hen/year ---
# Source: @MacLeod.2013 p.105 — SSA average laying rate for backyard poultry
# Value: 45 eggs per hen per year (used to estimate number of hens implied by egg production)
# Applied in: clean/animal_products.R — Section 3 (eggs), n_est calculation
# Code: eggs[, n_est := n_eggs / 45]
# Sensitivity: Tanzania-specific laying rates may differ (range in literature: 30–60 for
#   backyard systems). Sensitivity run: 30 eggs/hen/year (low) and 60 (high).
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

# --- ASSUMPTION A16: Feed conversion ratio 2.3 kg DM / kg eggs ---
# Source: @Alexander.2016 — FCR for egg production
# Value: need = produced (kg eggs) × 2.3 (kg DM feed per kg eggs)
# Applied in: clean/animal_products.R — Section 3 (eggs), mass_eggs computation
# Code: need = produced * 2.3
# Sensitivity: FCR is literature-derived and not Tanzania-specific. If backyard poultry
#   have higher feed efficiency (lower FCR), feed requirements would be overestimated.
#   Sensitivity run: FCR = 1.8 (low) and 3.0 (high) per @MacLeod.2013 range.
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

# --- ASSUMPTION A17: Egg consumption = missing - sold (recall-based imputation) ---
# Source: unknown — logic proposed in archive/04_Animal_products.Rmd lines 565–671
# Value: Egg consumption is derived as (produced - sold), augmented by recall data
#   from clean/recall.rds and household size from consumptionNPS4.dta.
#   consumptionNPS4.dta is NOT YET in 01_load_raw.R — must be added before stage 3.
# Applied in: clean/animal_products.R — placeholder comment only (not yet implemented)
# Sensitivity: Egg consumption is currently a placeholder (consumed = 0). This means
#   egg consumption is missing from the MFA until this is implemented.
# Action:
#   1. Add consumptionNPS4.dta to 01_load_raw.R
#   2. Implement recall-based egg consumption allocation (see archive/04_Animal_products.Rmd)
#   3. Decide: implement here in impute/ or in clean/animal_products.R
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

message("impute/animal_products.R: documentation registry loaded. No outputs produced.")
