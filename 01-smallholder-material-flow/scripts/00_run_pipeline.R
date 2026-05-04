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
source(here::here("01-smallholder-material-flow", "scripts", "impute", "animal_products.R"))
source(here::here("01-smallholder-material-flow", "scripts", "impute", "milk.R"))
source(here::here("01-smallholder-material-flow", "scripts", "impute", "destinations.R"))

# =============================================================================
# NOTE: stages 3-9 (build, exclusions audit, MFA, uncertainty, outputs)
# are pending restructuring.
#
# Planned stages (to be implemented):
#   03_build_households.R   — merge cleaned sections → one row per household
#   05_exclusions_audit.R   — profile all exclusions with counts and reasons
#                             EXISTS but runs after stage 3 (04_build_households.R)
#                             Do NOT source here until 04_build_households.R is written
#   06_mfa_input.R          — final dataset ready for MFA
#   07_mfa_analysis.R       — MFA + Monte Carlo
#   08_uncertainty.R        — uncertainty quantification (bootstrap + MC)
#                             All impute/ assumptions flagged for 08_uncertainty.R
#   09_outputs.R            — tables, charts, export
#
# Survey weighting: two candidate scripts archived (06.1_Survey_weighting.R and
# 0x_Weighting.R). One canonical weighting script must be selected before stage 3.
# See scripts/archive/README_archive.md for details.
# =============================================================================

message("00_run_pipeline.R: Stages 1-2b complete.")
