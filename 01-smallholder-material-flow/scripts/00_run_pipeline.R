# =============================================================================
# 00_run_pipeline.R
# PURPOSE: Run the full Project 01 pipeline in sequence
# Run this script to reproduce all outputs from raw data
# =============================================================================

library(here)

# =============================================================================
# STAGE 1: Load raw data
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "01_load_raw.R"))

# =============================================================================
# STAGE 2: Clean survey sections
# Each script reads from `raw` (produced by stage 1) and writes to
# data/processed/clean/<section>.rds
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "clean", "household_roster.R"))  # SPINE — run first
source(here::here("01-smallholder-material-flow", "scripts", "clean", "crops.R"))
source(here::here("01-smallholder-material-flow", "scripts", "clean", "recall.R"))
source(here::here("01-smallholder-material-flow", "scripts", "clean", "ag_produce.R"))
source(here::here("01-smallholder-material-flow", "scripts", "clean", "animals.R"))
source(here::here("01-smallholder-material-flow", "scripts", "clean", "animal_products.R"))
source(here::here("01-smallholder-material-flow", "scripts", "clean", "milk.R"))
source(here::here("01-smallholder-material-flow", "scripts", "clean", "destinations.R"))

# =============================================================================
# STAGE 2b: Imputation (documentation registries)
# Each script documents assumptions from the corresponding clean/ script.
# These registries should be reviewed before stage 3.
# The actual computation still runs in clean/ (above) to keep the pipeline runnable.
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "impute", "yield_gap.R"))
source(here::here("01-smallholder-material-flow", "scripts", "impute", "animals.R"))
source(here::here("01-smallholder-material-flow", "scripts", "impute", "recall.R"))
source(here::here("01-smallholder-material-flow", "scripts", "impute", "crops.R"))
source(here::here("01-smallholder-material-flow", "scripts", "impute", "ag_produce.R"))
source(here::here("01-smallholder-material-flow", "scripts", "impute", "processed_crops.R"))
source(here::here("01-smallholder-material-flow", "scripts", "impute", "animal_products.R"))
source(here::here("01-smallholder-material-flow", "scripts", "impute", "milk.R"))
source(here::here("01-smallholder-material-flow", "scripts", "impute", "destinations.R"))

# =============================================================================
# STAGE 3: Build household-level dataset
# Joins all section outputs into one row per household.
# Resolves cross-section dependencies (C02–C06).
# Applies structural zero guards.
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "04_build_households.R"))

# =============================================================================
# STAGE 4: Exclusions audit
# Profile all exclusions from clean/ and 04_build_households.R with counts and reasons.
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "05_exclusions_audit.R"))

# =============================================================================
# STAGE 5: MFA input preparation
# Prepare household-level input matrix (flow allocation, residue, mass balance).
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "06_mfa_input.R"))

# =============================================================================
# STAGE 6: MFA analysis
# Run Multiple Factor Analysis; extract factor scores, loadings, variance.
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "07_mfa_analysis.R"))

# =============================================================================
# STAGE 7: Uncertainty quantification
# Monte Carlo simulation over key parameter assumptions.
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "08_uncertainty.R"))

# =============================================================================
# STAGE 8: Outputs
# Generate all tables, charts, and export files.
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "09_outputs.R"))

# =============================================================================
# NOTE: Survey weighting — two candidate scripts archived (06.1_Survey_weighting.R
# and 0x_Weighting.R). One canonical weighting script must be selected and integrated
# before publishing final results. See scripts/archive/README_archive.md for details.
# See backlog.md B04.
# =============================================================================

message("00_run_pipeline.R: All stages complete.")
