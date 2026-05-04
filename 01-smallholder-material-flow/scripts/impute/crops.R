# =============================================================================
# impute/crops.R
# PURPOSE: Document all assumptions embedded in clean/crops.R
#          This script is a documentation registry only — the actual computation
#          code runs in clean/crops.R to keep the pipeline sequential.
#          When 04_build_households.R is written, consider moving logic that
#          requires cross-section context here or to build_households.
# INPUT:   (none — documentation only in current form)
# OUTPUT:  (none — see clean/crops.R for pipeline output)
# NOTE:    Run AFTER clean/crops.R
# =============================================================================

library(here)
library(tidyverse)

# =============================================================================
# ASSUMPTIONS REGISTRY — sourced from clean/crops.R
# =============================================================================

# --- ASSUMPTION A02: GPS area zero recoding ---
# Source: LSMS team recommendation (expert judgement)
# Value: gps_area == 0 is recoded to NA (GPS reading of 0 treated as unreliable,
#   not a true zero-area plot)
# Applied in: clean/crops.R — plots section, inside upData()
# Code: gps_area_new = ifelse(gps_area == 0, NA, gps_area_new)
# Sensitivity: If changed to retain 0, all plots with GPS = 0 would be treated
#   as having zero area, resulting in infinite yield calculations and likely
#   exclusion of those plots from yield gap analysis.
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

# --- ASSUMPTION A03: GPS preferred over farmer area estimate ---
# Source: LSMS team recommendation / standard practice (expert judgement)
# Value: plotsize = GPS area where available; farmer estimate used as fallback.
#   Rule: plotsize = if(gps_area_new != 0, gps_area_new, area_new)
#         plotsize = if(is.na(gps_area_new), area_new, plotsize)
# Applied in: clean/crops.R — composite plot size section
# Code:
#   p[, plotsize := ifelse(gps_area_new != 0, gps_area_new, area_new)]
#   p[, plotsize := ifelse(is.na(gps_area_new), area_new, plotsize)]
# Sensitivity: If farmer estimates used throughout, yield estimates would be
#   biased if farmers systematically over- or under-report plot area vs GPS.
#   Literature suggests farmers tend to overestimate (LSMS-ISA data).
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

# --- ASSUMPTION A04: Alternative area harvested scaling ---
# Source: data-derived (GPS / farmer ratio applied proportionally)
# Value: area_harvested_alt = (area_harvested_new / area_new) * plotsize
#   Rescales the farmer-reported area harvested by the GPS-to-farmer area ratio,
#   to get a GPS-consistent harvested area estimate.
# Applied in: clean/crops.R — crop-plot merge section
# Code: pc[, area_harvested_alt := area_harvested_new / area_new * plotsize]
# Sensitivity: If GPS measure and farmer estimate diverge widely, this scaling
#   will produce harvested areas that are very different from reported values.
#   The mismatch flag (mismatch := area_harvested_com > plotsize) captures extreme cases.
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

# --- ASSUMPTION A05: Total harvest = harvest_remain + quant_harvest ---
# Source: data-derived / survey design (expert judgement)
# Value: total_harvest = harvest_remain + quant_harvest
#   Assumes all remaining harvest (not yet collected) will eventually be collected.
# Applied in: clean/crops.R — crop-plot merge section
# Code: pc[, total_harvest := harvest_remain + quant_harvest]
# Sensitivity: If crop is later abandoned (common in smallholder systems), total_harvest
#   would overestimate actual yield. Sensitivity: run with total_harvest = quant_harvest
#   only (ignoring harvest_remain) as an alternative estimate.
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

message("impute/crops.R: documentation registry loaded. No outputs produced.")
