# =============================================================================
# impute/ag_produce.R
# PURPOSE: Document all assumptions embedded in clean/ag_produce.R
#          This script is a documentation registry only — the actual computation
#          code runs in clean/ag_produce.R to keep the pipeline sequential.
# INPUT:   (none — documentation only in current form)
# OUTPUT:  (none — see clean/ag_produce.R for pipeline output)
# NOTE:    Run AFTER clean/ag_produce.R
# =============================================================================

library(here)
library(tidyverse)

# =============================================================================
# ASSUMPTIONS REGISTRY — sourced from clean/ag_produce.R
# =============================================================================

# --- ASSUMPTION A06: Volume-to-kg conversion factors for processed products ---
# Source: https://www.aqua-calc.com/calculate/food-volume-to-weight — unknown per item
#   🚩 FLAG [ASSUMPTION]: source required for each row — several are NA (no reliable source)
# Value: Product-specific litre-to-kg density factors; see ap_conv table in clean/ag_produce.R.
#   Multiple entries are NA — those rows will produce NA in produced_kg.
# Applied in: clean/ag_produce.R — Section 2 (unit conversion), ap_conv table
# Sensitivity: Items with missing (NA) conversion factors will produce NA volumes throughout
#   the pipeline. Unknown how many households or kg-equivalents are affected — profile
#   in 05_exclusions_audit.R. Items with incorrect factors will bias MFA inputs.
# Action: Source additional density factors or mark as unresolvable before stage 3.
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

# Key NA conversions requiring resolution:
# - maize: flour NA? (0.49 exists) — check if all combos covered
# - palm oil: multiple NAs (flour, wet husk, pulp, seed)
# - sunflower: juice NA, flour 0.27 (verify)
# - cocoa: other NA
# - banana: juice NA, other NA
# - bulrush millet: thread NA
# - cassava: outer cover NA

# --- ASSUMPTION A07: Input allocation rules (heuristic) ---
# Source: unknown — expert judgement / data-derived
# Value: Heuristic rules assigning raw input quantities to products and by-products:
#   - Single product (prod==1, byprod==0): new_input = input
#   - Single by-product (prod==0, byprod==1): new_input = input
#   - Product + by-product with input/quant == 2: new_input = input / 2 (equal split)
#   - Two products with input/quant == 2: new_input = input / 2 (equal split)
#   - Three products: new_input = total quantity
#   - Progressive fallbacks for remaining cases (frac-based)
# Applied in: clean/ag_produce.R — Section 3 (product reconciliation), input_stats
# Sensitivity: Heuristic rules are not codebook-derived. Different allocation assumptions
#   would redistribute inputs across products, changing MFA input quantities.
#   Unknown magnitude — profile uncertain rows in 05_exclusions_audit.R.
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

# --- ASSUMPTION A08: Household 3208-001 input divided by 2 ---
# Source: manual inspection of raw data (data-derived)
# Value: y4_hhid == "3208-001" → new_input = input / 2
#   Applied because the raw input appears double-counted for this household.
# Applied in: clean/ag_produce.R — Section 3, input_stats2
# Code: new_input = ifelse(y4_hhid == "3208-001", input / 2, new_input)
# Sensitivity: If raw data changes or re-inspection shows the duplication was correct,
#   this household's input would be halved incorrectly. Single-household impact.
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

# --- ASSUMPTION A09: Remaining unresolved input assigned full input as fallback ---
# Source: unknown — fallback rule (expert judgement)
# Value: If new_input is still NA after all heuristic rules, assign full input quantity.
#   Applies to approximately 1 record in the data.
# Applied in: clean/ag_produce.R — Section 3, input_stats (final step)
# Code: new_input = ifelse(is.na(new_input), input, new_input)
# Sensitivity: Small number of records (n ≈ 1). Profile in 05_exclusions_audit.R.
#   Alternative: exclude these rows rather than using full input as fallback.
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

message("impute/ag_produce.R: documentation registry loaded. No outputs produced.")
