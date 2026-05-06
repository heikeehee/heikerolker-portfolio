# =============================================================================
# 07_mfa_analysis.R
# PURPOSE: Run Multiple Factor Analysis (MFA) on household input matrix
# INPUT:   data/processed/mfa_input.rds
# OUTPUT:  data/processed/mfa_results.rds — factor scores + variable loadings
# PACKAGE: FactoMineR
# =============================================================================
#
# SOURCE LOGIC FROM:
#   archive/06_Summary.Rmd — MFA variable groupings; mass-balance inputs
#   archive/99_C3a.Rmd     — factor score extraction; Sankey/MFA output logic
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

install.packages("FactoMineR")
library(FactoMineR)

# =============================================================================
# SECTION 1: LOAD INPUT
# =============================================================================

mfa_input <- readRDS(here::here("data", "processed", "01", "mfa_input.rds"))

# Remove household ID for MFA (non-numeric)
mfa_data <- mfa_input |>
  select(-y4_hhid) |>
  # Remove rows that are all-NA or all-zero (non-producing households)
  # 🚩 FLAG [ASSUMPTION]: rows with all-zero numeric values are retained in MFA.
  # If excluded, MFA may not represent the full population. See backlog B01 (imputation
  # sensitivity) in 08_uncertainty.R and backlog.md.
  filter(!if_all(where(is.numeric), ~ is.na(.)))

# =============================================================================
# SECTION 2: DEFINE MFA VARIABLE GROUPS
# Source logic: archive/06_Summary.Rmd — groupings by production system component
# =============================================================================

# Variable groups for MFA() call:
#   Group 1 — Crop production volumes:   log_harvest, log_harvest_trees, log_harvest_total
#   Group 2 — Crop flow allocation:      share_sold, share_consumed, share_stored
#   Group 3 — Crop mass-balance quality: unc_ratio_crops
#   Group 4 — Livestock products (milk): log_produced_milk, sold_milk, consumed_milk, unc_ratio_milk
#   Group 5 — Livestock products (eggs): log_produced_eggs, sold_eggs, consumed_eggs
#   Group 6 — Slaughter products:        log_slaughter, sold_animals, consumed_animals, meat, offal
#   Group 7 — Feed & residue:            residue_DM_total, grazing_res_total,
#                                         feed_animals_kgDM, grazed_kgDM

# 🚩 FLAG [ASSUMPTION]: variable groupings for MFA — [crop volumes, crop flows,
# crop quality, milk, eggs, slaughter, feed/residue] — confirm matches thesis grouping.
# These groups weight each block equally in the MFA regardless of number of variables.

group_sizes <- c(
  3,  # Group 1: Crop production volumes (log_harvest, log_harvest_trees, log_harvest_total)
  3,  # Group 2: Crop flow allocation (share_sold, share_consumed, share_stored)
  1,  # Group 3: Crop mass-balance quality (unc_ratio_crops)
  4,  # Group 4: Milk (log_produced_milk, sold_milk, consumed_milk, unc_ratio_milk)
  3,  # Group 5: Eggs (log_produced_eggs, sold_eggs, consumed_eggs)
  5,  # Group 6: Slaughter products (log_slaughter, sold_animals, consumed_animals, meat, offal)
  4   # Group 7: Feed & residue (residue_DM_total, grazing_res_total, feed_animals_kgDM, grazed_kgDM)
)

group_names <- c("Crop volumes", "Crop flows", "Crop quality",
                 "Milk", "Eggs", "Slaughter", "Feed & residue")

# =============================================================================
# SECTION 3: HANDLE MISSING VALUES
# =============================================================================

# 🚩 FLAG [ASSUMPTION]: missing values imputed with column means before MFA.
# FactoMineR's MFA() can handle NA via imputeMFA from missMDA if available.
# Current approach: mean imputation as fallback — conservative, introduces bias.
# Revisit with missMDA::imputeMFA() before final publication.
mfa_data_imputed <- mfa_data |>
  mutate(across(where(is.numeric), ~ ifelse(is.na(.), mean(., na.rm = TRUE), .)))

# =============================================================================
# SECTION 4: RUN MFA
# =============================================================================

# 🚩 FLAG [ASSUMPTION]: number of dimensions retained = 5 — justify against scree plot in 09_outputs.R
# Standard practice: retain dimensions explaining ≥5% variance or until cumulative ≥70%.
# Check eigenvalue plot produced in 09_outputs.R (FIGURE 2: Scree plot) before publishing.
n_dim <- 5

set.seed(2024)  # reproducibility

mfa_res <- MFA(
  base = dplyr::select(mfa_data_imputed, -product_kg, -byproduct_kg),
  group      = group_sizes,
  type       = rep("s", length(group_sizes)),
  ncp        = n_dim,
  name.group = group_names,
  graph      = FALSE
)

# =============================================================================
# SECTION 5: EXTRACT OUTPUTS
# =============================================================================

# Factor scores (one row per household)
# Align y4_hhid by filtering mfa_input to the same rows as mfa_data
# Note: both filter the same condition (all-NA rows) — keep filter logic identical
mfa_input_filtered <- mfa_input |>
  filter(!if_all(where(is.numeric) & !matches("^y4_hhid$"), ~ is.na(.)))

mfa_scores <- as.data.frame(mfa_res$ind$coord)
colnames(mfa_scores) <- paste0("Dim", seq_len(n_dim))
mfa_scores$y4_hhid   <- mfa_input_filtered$y4_hhid
mfa_scores <- mfa_scores |> select(y4_hhid, everything())

# Variable loadings (contributions of each variable to each dimension)
mfa_loadings <- as.data.frame(mfa_res$quanti.var$coord)
colnames(mfa_loadings) <- paste0("Dim", seq_len(n_dim))
mfa_loadings$variable <- rownames(mfa_loadings)
mfa_loadings <- mfa_loadings |> select(variable, everything())

# Variance explained (eigenvalues)
mfa_variance <- as.data.frame(mfa_res$eig)
mfa_variance$component <- rownames(mfa_variance)
mfa_variance <- mfa_variance |> select(component, everything())

# =============================================================================
# SECTION 6: SAVE
# =============================================================================

saveRDS(list(
  mfa_object  = mfa_res,
  scores      = mfa_scores,
  loadings    = mfa_loadings,
  variance    = mfa_variance
), here::here("data", "processed", "01", "mfa_results.rds"))

message("07_mfa_analysis.R: MFA complete. ",
        nrow(mfa_scores), " households × ", n_dim, " dimensions retained.")
message("  Variance explained (Dim 1-", n_dim, "): ",
        paste(round(mfa_variance[seq_len(n_dim), "percentage of variance"], 1), collapse = "%, "), "%")
