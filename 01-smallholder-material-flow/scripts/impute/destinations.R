# =============================================================================
# impute/destinations.R
# PURPOSE: Document all assumptions embedded in clean/destinations.R
#          This script is a documentation registry only — the actual computation
#          code runs in clean/destinations.R to keep the pipeline sequential.
# INPUT:   (none — documentation only in current form)
# OUTPUT:  (none — see clean/destinations.R for pipeline output)
# NOTE:    Run AFTER clean/destinations.R
# =============================================================================

library(here)
library(tidyverse)

# =============================================================================
# ASSUMPTIONS REGISTRY — sourced from clean/destinations.R
# =============================================================================

# --- ASSUMPTION A24: Household 8659-001, maize consumed := 480 ---
# Source: manual inspection of raw data (data-derived)
# Value: crop_disp[y4_hhid == "8659-001" & cropid == "maize", consumed := 480]
#   Original value was implausibly large (data entry error). Verified against raw data.
#   Corrected value 480 kg assigned by inspection.
# Applied in: clean/destinations.R — Section 1 (crop disposition), manual fix
# Sensitivity: Single-household impact. Flag for re-review if raw data changes.
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

# --- ASSUMPTION A25: Residue:Production Ratio (RPR) and Dry Matter fraction from FAOSTAT ---
# Source: FAOSTAT Tanzania country data — Tanzania-specific but country-level averages
#   URL: https://www.fao.org/faostat/en/#data/GA (Agri-Environmental Indicators → Crop Residues)
#   Downloaded: [date unknown — 🚩 FLAG: add download date to 01_load_raw.R comment]
# Value: RPR (Residue:Production Ratio) and Dry_matter (fraction) from FAOSTAT per crop.
#   Applied as:
#     Residues_DM     = harvest × Dry_matter × RPR × UsedRes
#     Residues_wet    = harvest × RPR × UsedRes
#     Residues_DM_alt = (harvest + quant_unharvested) × Dry_matter × RPR × UsedRes
# Applied in: clean/destinations.R — Section 4 (residue estimation)
# Sensitivity: Country-level FAOSTAT averages mask within-country variation (region,
#   variety, management). Plot- or crop-variety-specific RPR data not available.
#   Sensitivity run: ±20% on RPR values to bound uncertainty in residue estimates.
#   Regional FAOSTAT data may be available for some crops — check before stage 3.
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

message("impute/destinations.R: documentation registry loaded. No outputs produced.")
