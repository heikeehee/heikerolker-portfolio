# =============================================================================
# impute/recall.R
# PURPOSE: Document all assumptions embedded in clean/recall.R
#          This script is a documentation registry only — the actual conversion
#          code runs in clean/recall.R to keep the pipeline sequential.
#          When 04_build_households.R is written, consider moving unit conversion
#          logic here if it requires household-level context.
# INPUT:   (none — documentation only in current form)
# OUTPUT:  (none — see clean/recall.R for pipeline output)
# NOTE:    Run AFTER clean/recall.R to validate conversion factors
# =============================================================================

library(here)
library(tidyverse)

# =============================================================================
# ASSUMPTIONS REGISTRY — sourced from clean/recall.R
# =============================================================================

# --- ASSUMPTION A01: Food item unit conversion factors ---
# Source: literature / standard density references — unknown — 🚩 FLAG [ASSUMPTION]: source required per item
# Value: Product-specific conversion factors from (unit) → kg; see food_conv table in clean/recall.R
# Sensitivity: Items with incorrect conversion factors will propagate bias to all
#   downstream household consumption estimates. Any item currently returning NA
#   will be excluded from consumption totals — unknown how many households affected.
# Applied in: clean/recall.R — food_conv table (lines ~32–79)
# Action: Review each factor against the LSMS codebook or a verified reference.
#   Items with NA conversion must be resolved before stage 3.
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

# Key factors requiring priority review:
# - fresh milk: 1.08 (standard density of whole milk)
# - eggs/pieces: 0.0408 kg (approx 40.8g per egg — compare with 41.26g in clean/animal_products.R)
#   ⚠️  Inconsistency: recall.R uses 0.0408, animal_products.R uses 41.26g (0.04126 kg)
#   Resolve before stage 3.
# - cooking oil/litre: 0.9
# - buns, cakes, biscuits/litre: 0.02 (very low — verify)

message("impute/recall.R: documentation registry loaded. No outputs produced.")
