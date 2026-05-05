# =============================================================================
# impute/milk.R
# PURPOSE: Document all assumptions embedded in clean/milk.R
#          This script is a documentation registry only — the actual computation
#          code runs in clean/milk.R to keep the pipeline sequential.
# INPUT:   (none — documentation only in current form)
# OUTPUT:  (none — see clean/milk.R for pipeline output)
# NOTE:    Run AFTER clean/milk.R
# =============================================================================

library(here)
library(tidyverse)

# =============================================================================
# ASSUMPTIONS REGISTRY — sourced from clean/milk.R
# =============================================================================

# --- ASSUMPTION A18: Three households — missing milk average filled by inspection ---
# Source: manual inspection of raw data (data-derived)
# Value: lf06_03 (daily average milk production) is missing for 3 households.
#   Filled as follows:
#   - 1001-001: lf06_03 = lf06_05_2 (lo — only lowest value reported)
#   - 1002-001: lf06_03 = (lf06_05_2 + lf06_04_2) / 2 (midpoint of hi and lo)
#   - 2943-001: lf06_03 = lf06_07 + lf06_08 + lf06_10 (sum of dispositions)
# Applied in: clean/milk.R — Section 1 (load and rename), manual fix block
# Sensitivity: Three households only. If these were excluded instead, impact on
#   population estimates would be negligible. Rationale documented in archived 04_Milk.Rmd.
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

# --- ASSUMPTION A19: processed = psold when processed < psold ---
# Source: unknown — expert judgement (data inconsistency resolution)
# Value: If processed quantity < quantity sold from processing, set processed = psold.
#   Treats reported sales as a lower bound on processing volume.
# Applied in: clean/milk.R — Section 2 (reconciliation), processed_new derivation
# Code: processed_new = ifelse(processed < psold, psold, processed)
# Sensitivity: Affects households where psold > processed (data inconsistency).
#   Alternative: use processed as reported and flag psold > processed as an exclusion.
#   Review whether processing or sales data is more reliable in NPS4 context.
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

# --- ASSUMPTION A20: Standard deviation = range / 4 ---
# Source: standard statistical approximation (range ≈ 4σ for normal distribution)
# Value: SD = (corrected_max - corrected_min) / 4
#   Applied when min and max milk production are reported but no SD is available.
# Applied in: clean/milk.R — Section 2 (reconciliation), SD derivation
# Code: SD = ifelse(is.na(range), NA, range / 4)
# Sensitivity: This approximation assumes a normal distribution of daily milk yield,
#   which may not hold for smallholder herds. Alternative: use a Beta or PERT
#   distribution to better reflect asymmetric uncertainty. See A21 below.
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

# --- ASSUMPTION A21: PERT-like weighting for representative milk average ---
# Source: data-derived / expert judgement — method chosen empirically
# Value: new_av = 0.2 * corrected_min + 0.6 * corrected_avg + 0.2 * corrected_max
#   This PERT-like weighting was selected because it produced the fewest exclusions (n=92)
#   compared with other averaging methods tested in archived 04_Milk.Rmd.
# Applied in: clean/milk.R — Section 2 (reconciliation), new_av derivation
# Code: new_av = ifelse(av == smd1, av, 0.2*corrected_min + 0.6*corrected_avg + 0.2*corrected_max)
# Sensitivity: Compared with simple average, weighted_av, and geometric average in archived
#   04_Milk.Rmd. Sensitivity run: use simple_av = (av + hi + lo) / 3 as alternative.
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

# --- ASSUMPTION A22: Feed fraction tables for milk production (duplicated from impute/animals.R) ---
# Source: @Opio.2013 p.119 (small ruminants), p.117 (dairy cattle) — SSA-level averages
# Value: Feed fractions by animal type and feeding practice for milk production:
#   Small ruminants (@Opio.2013 p.119):
#     - only feeding:                 feed = 1.00, grazed = 0.00
#     - mainly grazing/scavenging:    feed = 0.35, grazed = 0.65
#     - only grazing/scavenging:      feed = 0.00, grazed = 1.00
#     - mainly feeding, some grazing: feed = 0.65, grazed = 0.35
#     - tethering:                    feed = 0.50, grazed = 0.50
#   Large ruminants / dairy cattle (@Opio.2013 p.117):
#     - only feeding:                 feed = 1.00, grazed = 0.00
#     - mainly grazing/scavenging:    feed = 0.25, grazed = 0.75
#     - only grazing/scavenging:      feed = 0.00, grazed = 1.00
#     - mainly feeding, some grazing: feed = 0.75, grazed = 0.25
#     - tethering:                    feed = 0.50, grazed = 0.50
# Applied in: clean/milk.R — Section 4 (milk feed requirements), smrum / lgrum tables
# Note: These tables are also defined in impute/animals.R. Maintenance risk: if values
#   change, both files must be updated. Consolidate into a shared reference file
#   (data/reference/feed_fractions.csv) when pipeline is stable.
# Sensitivity: SSA-level averages. Tanzania-specific ruminant feeding may differ.
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

# --- ASSUMPTION A23: Feed conversion ratio 0.7 kg DM / kg milk ---
# Source: @Alexander.2016 — FCR for milk production
# Value: need = milk (kg) × 0.7 (kg DM feed per kg milk)
#   Applied uniformly to both small and large ruminants.
# Applied in: clean/milk.R — Section 4 (milk feed requirements)
# Code: need = milk * 0.7
# Sensitivity: FCR is literature-derived and not Tanzania-specific. Dairy cattle and
#   small ruminants likely have different FCRs. Sensitivity run: separate FCRs for
#   large ruminants (0.8) and small ruminants (0.6) per @Opio.2013 range.
# 🚩 FLAG [ASSUMPTION]: retained from clean/ review — confirm value before running 08_uncertainty.R

message("impute/milk.R: documentation registry loaded. No outputs produced.")
