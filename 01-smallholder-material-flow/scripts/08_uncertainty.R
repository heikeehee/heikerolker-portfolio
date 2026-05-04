# =============================================================================
# 08_uncertainty.R
# PURPOSE: Quantify uncertainty in MFA outputs via Monte Carlo simulation
# INPUT:   data/processed/mfa_input.rds
#          impute/yield_gap.R assumption ranges
#          impute/animals.R assumption ranges
# OUTPUT:  data/processed/uncertainty_results.rds
#
# BACKLOG: Imputation sensitivity analysis (excluded vs imputed households)
# not yet implemented — see FLAGS_REVIEW.md and backlog.md
# This is a known methodological limitation carried forward from the thesis.
# When revisited: run MFA twice (exclusions as-is vs imputed dataset) and
# report whether conclusions change. Affects projects 02 and 03 downstream.
# =============================================================================
#
# SOURCE LOGIC FROM:
#   archive/06_Summary.Rmd — mass-balance uncertainty (missing/unallocated pattern)
#   archive/99_C3a.Rmd     — uncertainty_milk_stats, uncertainty_crops_stats
#                            upper/lower/mean approach from mass-balance residuals
#                            weighted vs unweighted uncertainty estimates
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

library(FactoMineR)

# =============================================================================
# SECTION 1: LOAD INPUTS
# =============================================================================

mfa_input   <- readRDS(here::here("data", "processed", "mfa_input.rds"))
mfa_results <- readRDS(here::here("data", "processed", "mfa_results.rds"))

# =============================================================================
# SECTION 2: PARAMETER RANGES FOR MONTE CARLO
# Source logic: impute/yield_gap.R and impute/animals.R assumption ranges
# Each range below corresponds to a flagged assumption in FLAGS_REVIEW.md
# =============================================================================

# 🚩 FLAG [ASSUMPTION]: Monte Carlo n = 1000 — justify
# Standard for this type of analysis; increase to 5000+ before final publication
# if computational resources allow. Runtime scales linearly with n.
mc_n    <- 1000
mc_seed <- 2024

# Milk density conversion factor
# 🚩 FLAG [ASSUMPTION]: parameter range for milk_density = [1.02, 1.04]
# Central value 1.03 kg/litre (clean/milk.R). Range ±0.01 based on published
# variation in fresh whole milk density (FAO conventions; Codex Alimentarius).
# B03 in backlog.md — confirm against LSMS-ISA documentation.
milk_density_range <- c(low = 1.02, mid = 1.03, high = 1.04)

# Crop loss rate uncertainty
# 🚩 FLAG [ASSUMPTION]: parameter range for loss_rate = [0.5×, 1.5×] observed rate
# Loss is reported as a proportion of harvest (ag5a_31 / 10).
# Sensitivity: multiply observed rate by a random factor drawn from Uniform(0.5, 1.5).
# Source: A25 in FLAGS_REVIEW.md (FAOSTAT RPR ±20% sensitivity)
loss_rate_multiplier_range <- c(low = 0.5, high = 1.5)

# Egg laying rate
# 🚩 FLAG [ASSUMPTION]: parameter range for egg_laying_rate = [30, 60] eggs/hen/year
# Central value 45 (A15 in FLAGS_REVIEW.md). Range from MacLeod.2013 SSA values.
egg_laying_range <- c(low = 30, mid = 45, high = 60)

# Feed conversion ratio — milk
# 🚩 FLAG [ASSUMPTION]: parameter range for FCR_milk = [0.6, 0.8] kg DM/kg milk
# Central value 0.7 (A23 in FLAGS_REVIEW.md). Alexander.2016.
# Sensitivity: separate FCRs for large (high) and small ruminants (low).
fcr_milk_range <- c(low = 0.6, mid = 0.7, high = 0.8)

# RPR (Residue to Product Ratio) uncertainty
# 🚩 FLAG [ASSUMPTION]: parameter range for RPR = ±20% around FAOSTAT Tanzania values
# A25 in FLAGS_REVIEW.md. Sensitivity to whether regional FAOSTAT data would differ.
rpr_multiplier_range <- c(low = 0.8, high = 1.2)

# =============================================================================
# SECTION 3: MONTE CARLO SIMULATION
# Approach: perturb key input parameters, re-derive MFA input matrix,
# re-run MFA, record factor scores. CI = percentile interval across iterations.
# =============================================================================

set.seed(mc_seed)

# Prepare base MFA data (numeric columns only, mean-imputed as in 07_mfa_analysis.R)
base_data <- mfa_input |>
  select(-y4_hhid) |>
  filter(!if_all(where(is.numeric), ~ is.na(.))) |>
  mutate(across(where(is.numeric), ~ ifelse(is.na(.), mean(., na.rm = TRUE), .)))

# Group structure (must match 07_mfa_analysis.R exactly)
group_sizes <- c(3, 3, 1, 4, 3, 5, 4)
group_names <- c("Crop volumes", "Crop flows", "Crop quality",
                 "Milk", "Eggs", "Slaughter", "Feed & residue")
n_dim <- 5

mc_scores <- vector("list", mc_n)

for (i in seq_len(mc_n)) {

  # Draw perturbation factors from uniform distributions
  milk_density_i    <- runif(1, milk_density_range["low"],  milk_density_range["high"])
  loss_mult_i       <- runif(1, loss_rate_multiplier_range["low"], loss_rate_multiplier_range["high"])
  rpr_mult_i        <- runif(1, rpr_multiplier_range["low"], rpr_multiplier_range["high"])
  egg_rate_i        <- runif(1, egg_laying_range["low"],    egg_laying_range["high"])

  # Perturb the input matrix
  perturbed <- base_data |>
    mutate(
      # Milk production: re-scale by ratio of perturbed to central density
      log_produced_milk = log1p(expm1(log_produced_milk) * (milk_density_i / milk_density_range["mid"])),
      sold_milk         = sold_milk  * (milk_density_i / milk_density_range["mid"]),
      consumed_milk     = consumed_milk * (milk_density_i / milk_density_range["mid"]),
      unc_ratio_milk    = unc_ratio_milk * (milk_density_i / milk_density_range["mid"]),

      # Egg production: re-scale by ratio of perturbed to central laying rate
      log_produced_eggs = log1p(expm1(log_produced_eggs) * (egg_rate_i / egg_laying_range["mid"])),

      # Residue: perturb proportionally to RPR uncertainty
      residue_DM_total  = residue_DM_total  * rpr_mult_i,
      grazing_res_total = grazing_res_total * rpr_mult_i
    )

  # Re-run MFA with perturbed data
  mfa_i <- tryCatch(
    MFA(perturbed, group = group_sizes, type = rep("s", length(group_sizes)),
        ncp = n_dim, name.group = group_names, graph = FALSE),
    error = function(e) NULL
  )

  if (!is.null(mfa_i)) {
    mc_scores[[i]] <- as.data.frame(mfa_i$ind$coord)
    colnames(mc_scores[[i]]) <- paste0("Dim", seq_len(n_dim))
    mc_scores[[i]]$iteration <- i
  }
}

# Remove any failed iterations
mc_scores <- Filter(Negate(is.null), mc_scores)
message("08_uncertainty.R: ", length(mc_scores), "/", mc_n, " MC iterations succeeded.")

# =============================================================================
# SECTION 4: COMPUTE CONFIDENCE INTERVALS ON FACTOR SCORES
# Source logic: archive/99_C3a.Rmd — uncertainty_milk_stats pattern
# CI = 2.5th and 97.5th percentile across MC iterations (95% CI)
# =============================================================================

mc_all <- bind_rows(mc_scores)

mc_ci <- mc_all |>
  group_by(iteration) |>
  summarise(across(starts_with("Dim"), list(
    mean = mean,
    lo95 = ~ quantile(., 0.025, na.rm = TRUE),
    hi95 = ~ quantile(., 0.975, na.rm = TRUE)
  ), .names = "{.col}_{.fn}")) |>
  ungroup()

# Dimension-level summary across iterations (spread of factor scores)
dim_summary <- mc_all |>
  summarise(across(starts_with("Dim"), list(
    mean   = ~ mean(., na.rm = TRUE),
    sd     = ~ sd(., na.rm = TRUE),
    lo95   = ~ quantile(., 0.025, na.rm = TRUE),
    hi95   = ~ quantile(., 0.975, na.rm = TRUE)
  ), .names = "{.col}_{.fn}"))

# =============================================================================
# SECTION 5: MASS-BALANCE UNCERTAINTY FROM REPORTED DATA
# Source logic: archive/99_C3a.Rmd — uncertainty_crops_stats, uncertainty_milk_stats
# These use the upper/lower approach from mass-balance residuals (not MC)
# =============================================================================

# Load full households for mass-balance uncertainty
households <- readRDS(here::here("data", "processed", "households.rds"))

# 🚩 FLAG [ASSUMPTION]: upper estimate = produced + missing (assumes production underestimated)
#                        lower estimate = produced - unallocated (assumes production overestimated)
# This is the uncertainty model from archive/06_Summary.Rmd and 99_C3a.Rmd.
# It captures internal data consistency, not sampling uncertainty.

crops_unc <- mfa_input |>
  mutate(
    upper_harvest = harvest + (harvest * 0.3),  # +30% tolerance (E09 in FLAGS_REVIEW.md)
    lower_harvest = harvest - (harvest * 0.3),
    mean_harvest  = (upper_harvest + lower_harvest + harvest) / 3
  ) |>
  summarise(
    supper = sum(upper_harvest, na.rm = TRUE),
    slower = sum(lower_harvest, na.rm = TRUE),
    smean  = sum(mean_harvest,  na.rm = TRUE),
    stotal = sum(harvest,       na.rm = TRUE)
  ) |>
  mutate(row_stdev = apply(select(., supper, slower, smean, stotal), 1, sd, na.rm = TRUE))

milk_unc <- mfa_input |>
  mutate(
    upper_milk = log_produced_milk * (milk_density_range["high"] / milk_density_range["mid"]),
    lower_milk = log_produced_milk * (milk_density_range["low"]  / milk_density_range["mid"])
  ) |>
  summarise(
    supper = sum(upper_milk, na.rm = TRUE),
    slower = sum(lower_milk, na.rm = TRUE),
    stotal = sum(log_produced_milk, na.rm = TRUE)
  ) |>
  mutate(
    Mean      = rowMeans(select(., supper, slower, stotal), na.rm = TRUE),
    row_stdev = apply(select(., supper, slower, stotal), 1, sd, na.rm = TRUE)
  )

# =============================================================================
# SECTION 6: SAVE
# =============================================================================

saveRDS(list(
  mc_scores     = mc_all,
  mc_ci         = mc_ci,
  dim_summary   = dim_summary,
  crops_unc     = crops_unc,
  milk_unc      = milk_unc,
  parameters    = list(
    mc_n                    = mc_n,
    mc_seed                 = mc_seed,
    milk_density_range      = milk_density_range,
    loss_rate_multiplier    = loss_rate_multiplier_range,
    egg_laying_range        = egg_laying_range,
    fcr_milk_range          = fcr_milk_range,
    rpr_multiplier_range    = rpr_multiplier_range
  )
), here::here("data", "processed", "uncertainty_results.rds"))

message("08_uncertainty.R: Uncertainty results saved.")

# =============================================================================
# BACKLOG — not yet implemented
# =============================================================================
# 1. Imputation sensitivity: re-run MFA with imputed dataset vs exclusions-as-is
#    Compare factor scores — do conclusions change?
#    Required before publishing project 01 methods
#    Affects: 02-survey-harmonisation (sample composition), 03-food-system-segmentation (cluster membership)
#
# 2. Bootstrap CI on factor scores (if not already implemented above)
#
# 3. Sensitivity to MFA grouping choices (see 07_mfa_analysis.R flags)
# =============================================================================
