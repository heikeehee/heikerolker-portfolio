# =============================================================================
# 09_outputs.R
# PURPOSE: Generate all tables, charts, and export files from analysis results
# INPUT:   data/processed/mfa_results.rds
#          data/processed/uncertainty_results.rds
#          data/processed/households.rds
# OUTPUT:  outputs/tables/ and outputs/figures/
# =============================================================================
#
# SOURCE LOGIC FROM:
#   archive/06_Summary.Rmd — produce_long overview, summary stats
#   archive/xx_results.Rmd — Table 1 (production quantities), sales, consumption tables
#   archive/99_C3a.Rmd     — Sankey function, factor map, uncertainty plots
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

library(ggplot2)
library(ggalluvial)
library(tibble)

# Ensure output directories exist
dir.create(here::here("01-smallholder-material-flow", "outputs", "tables"),
           showWarnings = FALSE, recursive = TRUE)
dir.create(here::here("01-smallholder-material-flow", "outputs", "figures"),
           showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# LOAD INPUTS
# =============================================================================

households          <- readRDS(here::here("data", "processed", "households.rds"))
mfa_results         <- readRDS(here::here("data", "processed", "mfa_results.rds"))
uncertainty_results <- readRDS(here::here("data", "processed", "uncertainty_results.rds"))
mfa_input           <- readRDS(here::here("data", "processed", "mfa_input.rds"))

mfa_scores   <- mfa_results$scores
mfa_loadings <- mfa_results$loadings
mfa_variance <- mfa_results$variance

# =============================================================================
# --- TABLE 1: Household sample summary ---
# Source logic: archive/xx_results.Rmd (hhs_3a basic numbers block)
# =============================================================================

tab1 <- households |>
  summarise(
    n_households      = n(),
    n_crop_hh         = sum(crop_total_harvest_kg > 0, na.rm = TRUE),
    n_livestock_hh    = sum(milk_total_kg > 0 | egg_produced_kg > 0 |
                            animal_meat_kg > 0, na.rm = TRUE),
    mean_harvest_kg   = mean(crop_total_harvest_kg, na.rm = TRUE),
    median_harvest_kg = median(crop_total_harvest_kg, na.rm = TRUE)
  )

write.csv(tab1,
          here::here("01-smallholder-material-flow", "outputs", "tables", "table1_sample_summary.csv"),
          row.names = FALSE)
message("TABLE 1 saved: table1_sample_summary.csv")

# =============================================================================
# --- TABLE 2: Flow allocation by destination ---
# Source logic: archive/xx_results.Rmd (sales + consumption summary blocks)
# archive/99_C3a.Rmd — produce_long flow breakdown
# =============================================================================

# Crop flow allocation summary
# NOTE: mfa_input contains log-transformed harvest and share-based destination variables.
# For an interpretable flow allocation table, use share_sold/consumed/stored directly.
# Absolute kg by destination is available from mass_crops.rds if needed for publication.
tab2_crops <- mfa_input |>
  summarise(
    share_sold_mean     = mean(share_sold,     na.rm = TRUE),
    share_consumed_mean = mean(share_consumed, na.rm = TRUE),
    share_stored_mean   = mean(share_stored,   na.rm = TRUE),
    total_sold_milk_kg  = sm(sold_milk),
    total_cons_milk_kg  = sm(consumed_milk),
    total_sold_eggs_kg  = sm(sold_eggs),
    total_cons_eggs_kg  = sm(consumed_eggs),
    total_sold_animals  = sm(sold_animals)
  ) |>
  pivot_longer(everything(), names_to = "variable", values_to = "value")

write.csv(tab2_crops,
          here::here("01-smallholder-material-flow", "outputs", "tables", "table2_flow_allocation.csv"),
          row.names = FALSE)
message("TABLE 2 saved: table2_flow_allocation.csv")

# =============================================================================
# --- TABLE 3: MFA variable contributions ---
# Source logic: archive/99_C3a.Rmd — factor score and loading extraction
# =============================================================================

tab3 <- mfa_loadings |>
  arrange(desc(abs(Dim1)))

write.csv(tab3,
          here::here("01-smallholder-material-flow", "outputs", "tables", "table3_mfa_contributions.csv"),
          row.names = FALSE)
message("TABLE 3 saved: table3_mfa_contributions.csv")

# =============================================================================
# --- TABLE 4: Uncertainty summary ---
# Source logic: archive/99_C3a.Rmd — uncertainty_crops_stats, uncertainty_milk_stats
# =============================================================================

tab4 <- uncertainty_results$dim_summary

write.csv(tab4,
          here::here("01-smallholder-material-flow", "outputs", "tables", "table4_uncertainty_summary.csv"),
          row.names = FALSE)
message("TABLE 4 saved: table4_uncertainty_summary.csv")

# =============================================================================
# --- FIGURE 1: Flow diagram / Sankey ---
# Source logic: archive/99_C3a.Rmd — sankey() function and data preparation
# 🚩 FLAG [TABLEAU]: this chart is the candidate for Tableau Public — flow allocation by destination
# The plotly Sankey is best rendered interactively; export to Tableau for portfolio.
#
# utils/mfa_flow.R provides the canonical wrappers for Sankey construction:
#   - mfa_flow_grouped(data_list, group_var) — population-level flow, grouped by chosen variable
#   - mfa_flow_hh(data_list, hhid, group_var) — single-household flow (project 03 profiles)
#   - mfa_flow_all_hh(data_list, group_var)   — named list of flows per household (project 03)
# group_var default = "type" (food group). Alternatives: "region", "district".
# =============================================================================

# Requires: htmlwidgets — install.packages("htmlwidgets") if not present
# (also listed in packages.R)

# FIGURE 1: Material flow Sankey — all food types, built via mfafun() wrappers
# REPLACED: partial Sankey (milk + crops only) — see FIGURE 1a/1b below for full flow

# Guard: source mfa_flow.R if not already loaded (e.g. when running this script standalone)
if (!exists("mfa_flow_grouped")) {
  source(here::here("01-smallholder-material-flow", "scripts", "utils", "mfa_flow.R"))
}

# =============================================================================
# BUILD data_list FOR MFAFUN()
# 🚩 FLAG [ARCHITECTURE]: data_list uses raw mass flow files (long format, one row per
# household × food item), NOT mfa_input.rds (which is the wide household-level MFA
# matrix used in 07_mfa_analysis.R — see 06_mfa_input.R for the distinction).
# Column names confirmed from clean/destinations.R, clean/milk.R, clean/animal_products.R,
# impute/animals.R, and impute/processed_crops.R.
# =============================================================================

# Load raw mass flow files
mass_crops      <- setDT(zap_all(readRDS(here::here("data", "processed", "clean", "mass_crops.rds"))))
mass_trees      <- setDT(zap_all(readRDS(here::here("data", "processed", "clean", "mass_trees.rds"))))
mass_animals    <- setDT(zap_all(readRDS(here::here("data", "processed", "impute", "mass_animals.rds"))))
mass_hides      <- setDT(zap_all(readRDS(here::here("data", "processed", "clean", "mass_hides.rds"))))
mass_milk_final <- setDT(zap_all(readRDS(here::here("data", "processed", "clean", "mass_milk_final.rds"))))
mass_eggs       <- setDT(zap_all(readRDS(here::here("data", "processed", "clean", "mass_eggs.rds"))))
# processed_crops: y4_hhid, crop (str_to_title), sent_to_processing_kg, product_kg, byproduct_kg
processed_crops <- setDT(readRDS(here::here("data", "processed", "imputed", "processed_crops.rds")))

# =============================================================================
# data_list$crops: mass_crops + mass_trees + processing node from processed_crops
# mass_crops / mass_trees columns (clean/destinations.R):
#   y4_hhid, type, cropid, harvest, sold, stored, losses, consumed,
#   seed, payment, gifts, feed, smd  (mass_trees also has ntrees, yield)
# =============================================================================

crops_ct <- rbindlist(
  list(
    mass_crops[, .(y4_hhid, type, cropid,
                   consumed, sold, payment, gifts, losses, stored, feed, seed)],
    mass_trees[, .(y4_hhid, type, cropid,
                   consumed, sold, payment, gifts, losses, stored, feed, seed)]
  ),
  fill = TRUE
)

# Mass balance residual: missing = harvest − smd (unaccounted fraction, floored at 0)
# 🚩 FLAG [ASSUMPTION]: missing = max(harvest − smd, 0); negative balance set to 0
crops_mb <- rbindlist(
  list(
    mass_crops[, .(y4_hhid, cropid, harvest, smd)],
    mass_trees[, .(y4_hhid, cropid, harvest, smd)]
  ),
  fill = TRUE
)[, missing := pmax(as.double(harvest) - as.double(smd), 0)]

crops_ct <- merge(crops_ct, crops_mb[, .(y4_hhid, cropid, missing)],
                  by = c("y4_hhid", "cropid"), all.x = TRUE)
crops_ct[is.na(missing), missing := 0]

# Processing node: join processed_crops to get sent_to_processing, product, byproduct
# 🚩 FLAG [ASSUMPTION]: prodsold = product_kg (all product assumed sold — disaggregated
#   product sales not available without joining mass_agprod.rds; see backlog)
# 🚩 FLAG [ASSUMPTION]: prodconsumed = 0 (placeholder — see mass_agprod for split)
# 🚩 FLAG [ASSUMPTION]: waste = byproduct_kg (byproduct treated as waste node in Sankey)
processed_crops[, cropid := tolower(crop)]
proc_sum <- processed_crops[, .(
  processing   = sm(sent_to_processing_kg),
  prodsold     = sm(product_kg),
  prodconsumed = 0,
  waste        = sm(byproduct_kg)
), by = .(y4_hhid, cropid)]

crops_full <- merge(crops_ct, proc_sum, by = c("y4_hhid", "cropid"), all.x = TRUE)
setnafill(crops_full, fill = 0, cols = c("processing", "prodsold", "prodconsumed", "waste"))

# =============================================================================
# data_list$meat: mass_animals (impute/animals.R) + hides processing (mass_hides)
# mass_animals columns: y4_hhid, type, lvstckid, need, feed, grazed,
#   slaughter (count), total_weight (kg), cons_weight, sold_weight,
#   ew, meat, offal, hides, inedible
# mfafun() meat section uses: feed, grazed, slaughtered, sold, inedible,
#   meat, offal, hides, waste, prodproduced, prodsold, hides_cons
# 🚩 FLAG [ASSUMPTION]: slaughtered = total_weight (slaughter weight in kg, not head count)
# 🚩 FLAG [ASSUMPTION]: sold = sold_weight (live weight of animals sold)
# 🚩 FLAG [ASSUMPTION]: waste = 0 (no separate waste estimate in current pipeline)
# =============================================================================

meat_base <- mass_animals[, .(
  y4_hhid,
  type,
  feed,
  grazed,
  slaughtered = total_weight,
  sold        = sold_weight,
  inedible,
  meat,
  offal,
  hides,
  waste       = 0
)]

# Hides processing: prodproduced, prodsold, hides_cons from mass_hides
# mass_hides columns (clean/animal_products.R): y4_hhid, type, pprod, sold2, missing
# 🚩 FLAG [ASSUMPTION]: prodproduced = pprod  (hides produced, sent to tanning/processing)
# 🚩 FLAG [ASSUMPTION]: prodsold     = sold2  (hides sold as finished product)
# 🚩 FLAG [ASSUMPTION]: hides_cons   = missing (hides not sold, assumed household use)
hides_sum <- mass_hides[
  type %in% c("large ruminants", "small ruminants"),
  .(prodproduced = sm(pprod),
    prodsold     = sm(sold2),
    hides_cons   = sm(missing)),
  by = .(y4_hhid, type)
]

meat_full <- merge(meat_base, hides_sum, by = c("y4_hhid", "type"), all.x = TRUE)
setnafill(meat_full, fill = 0, cols = c("prodproduced", "prodsold", "hides_cons"))

# =============================================================================
# data_list$ap: mass_milk_final + mass_eggs (with product column added)
# mfafun() ap section uses: type, product, feed, grazed, produced,
#   consumed, sold, missing, processing, prodsold
# mass_milk_final key columns (clean/milk.R):
#   y4_hhid, type (large/small ruminants), feed, grazed,
#   milk_kg, consumed_kg, sold_kg, missing_kg, processed_new_kg, psold_kg
# mass_eggs key columns (clean/animal_products.R):
#   y4_hhid, type (poultry), produced, sold, consumed (=0 placeholder), missing, feed, grazed
# =============================================================================

milk_ap <- mass_milk_final[, .(
  y4_hhid,
  type,
  product      = "milk",
  feed,
  grazed,
  produced     = milk_kg,
  consumed     = consumed_kg,
  sold         = sold_kg,
  missing      = missing_kg,
  processing   = processed_new_kg,   # milk sent for processing (butter, yoghurt)
  prodsold     = psold_kg            # processed milk product sold
)]

# 🚩 FLAG [ASSUMPTION]: egg processing = 0 (no egg processing flow modelled yet)
# 🚩 FLAG [ASSUMPTION]: egg consumed = 0 placeholder — see impute/animal_products.R (A17)
eggs_ap <- mass_eggs[, .(
  y4_hhid,
  type,
  product      = "eggs",
  feed,
  grazed,
  produced,
  consumed,
  sold,
  missing,
  processing   = 0,
  prodsold     = 0
)]

ap_full <- rbindlist(list(milk_ap, eggs_ap), fill = TRUE)

# =============================================================================
# Assemble and validate data_list
# =============================================================================

data_list <- list(
  crops = crops_full,
  meat  = meat_full,
  ap    = ap_full
)

purrr::iwalk(data_list, \(df, nm)
  message("data_list$", nm, ": ", nrow(df), " rows, types: ",
          paste(unique(df$type), collapse = ", ")))

# --- FIGURE 1a: Population Sankey — all food types, grouped by type ---
flow_population <- mfa_flow_grouped(data_list, group_var = "type")
fig_sankey_pop  <- sankey(
  flow_population,
  title    = "Smallholder Food Flows — Tanzania NPS",
  subtitle = "All households · flows grouped by food type"
)
htmlwidgets::saveWidget(
  fig_sankey_pop,
  here::here("01-smallholder-material-flow", "outputs", "figures", "sankey_population.html"),
  selfcontained = TRUE
)
message("Saved: sankey_population.html")

# --- FIGURE 1b: Single household Sankey — demo (reproducible random draw) ---
set.seed(42)
demo_hhid     <- sample(unique(data_list$crops$y4_hhid), 1)
flow_hh_demo  <- mfa_flow_hh(data_list, hhid = demo_hhid, group_var = "type")
fig_sankey_hh <- sankey(
  flow_hh_demo,
  title    = paste("Household Food Flow — ID:", demo_hhid),
  subtitle = "Single household · food system profile by food type"
)
htmlwidgets::saveWidget(
  fig_sankey_hh,
  here::here("01-smallholder-material-flow", "outputs", "figures", "sankey_household_demo.html"),
  selfcontained = TRUE
)
message("Demo household: ", demo_hhid)
message("Saved: sankey_household_demo.html")

# NOTE: to view any household interactively:
# sankey(mfa_flow_hh(data_list, hhid = "YOUR_HHID"), title = "HH Flow")
# NOTE: to group by region instead of type:
# sankey(mfa_flow_grouped(data_list, group_var = "region"), title = "Regional Flows")

# 🚩 FLAG [TABLEAU]: export sankey_flows data for Tableau Public rebuild
write.csv(flow_population |> select(source, target, value),
          here::here("01-smallholder-material-flow", "outputs", "tables", "sankey_data.csv"),
          row.names = FALSE)

message("FIGURE 1 saved: sankey_population.html + sankey_household_demo.html (+ sankey_data.csv for Tableau)")

# =============================================================================
# --- FIGURE 2: Scree plot ---
# Source logic: archive/99_C3a.Rmd — variance explained from MFA object
# =============================================================================

fig2_data <- mfa_variance |>
  head(10) |>
  mutate(component = factor(component, levels = component))

fig2 <- ggplot(fig2_data, aes(x = component, y = `percentage of variance`)) +
  geom_col(fill = "#2166ac", alpha = 0.8) +
  geom_line(aes(group = 1), colour = "#d73027", linewidth = 0.8) +
  geom_point(colour = "#d73027", size = 2) +
  geom_hline(yintercept = 5, linetype = "dashed", colour = "grey50") +
  labs(
    title    = "Scree plot — MFA dimensions",
    subtitle = "Dashed line = 5% variance threshold",
    x        = "Dimension",
    y        = "% Variance explained"
  ) +
  theme_minimal()

ggsave(
  here::here("01-smallholder-material-flow", "outputs", "figures", "figure2_screeplot.png"),
  plot = fig2, width = 10, height = 6, dpi = 300
)
message("FIGURE 2 saved: figure2_screeplot.png")

# =============================================================================
# --- FIGURE 3: Factor map (household scores on Dim1 × Dim2) ---
# Source logic: archive/99_C3a.Rmd — MFA factor coordinates
# =============================================================================

# 🚩 FLAG [ASSUMPTION]: Dim1 vs Dim2 plotted as primary factor map.
# If Dim2 explains very little variance, Dim1 vs Dim3 may be more informative.
# Check scree plot (Figure 2) before deciding on axes for publication.
fig3_data <- mfa_scores |>
  left_join(select(households, y4_hhid), by = "y4_hhid")

fig3 <- ggplot(fig3_data, aes(x = Dim1, y = Dim2)) +
  geom_point(alpha = 0.4, colour = "#2166ac", size = 1.5) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey60") +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey60") +
  labs(
    title    = "MFA factor map — household scores",
    subtitle = paste0(
      "Dim1: ", round(mfa_variance[1, "percentage of variance"], 1), "% | ",
      "Dim2: ", round(mfa_variance[2, "percentage of variance"], 1), "%"
    ),
    x = paste0("Dimension 1 (",
                round(mfa_variance[1, "percentage of variance"], 1), "%)"),
    y = paste0("Dimension 2 (",
                round(mfa_variance[2, "percentage of variance"], 1), "%)")
  ) +
  theme_minimal()

ggsave(
  here::here("01-smallholder-material-flow", "outputs", "figures", "figure3_factor_map.png"),
  plot = fig3, width = 10, height = 6, dpi = 300
)
message("FIGURE 3 saved: figure3_factor_map.png")

# =============================================================================
# --- FIGURE 4: Uncertainty ranges ---
# Source logic: archive/99_C3a.Rmd — uncertainty_milk_stats distribution plot
# archive/99_C3a.Rmd — range_milk_fig pattern
# =============================================================================

mc_dim_long <- uncertainty_results$mc_scores |>
  pivot_longer(starts_with("Dim"), names_to = "dimension", values_to = "score")

fig4 <- mc_dim_long |>
  ggplot(aes(x = score, fill = dimension)) +
  geom_histogram(alpha = 0.6, bins = 40) +
  facet_wrap(~ dimension, scales = "free_x") +
  scale_fill_brewer(palette = "Set1", guide = "none") +
  labs(
    title    = "Monte Carlo uncertainty — MFA factor score distributions",
    subtitle = paste0("n = ", uncertainty_results$parameters$mc_n,
                      " iterations; seed = ", uncertainty_results$parameters$mc_seed),
    x        = "Factor score",
    y        = "Count"
  ) +
  theme_minimal()

ggsave(
  here::here("01-smallholder-material-flow", "outputs", "figures", "figure4_uncertainty_ranges.png"),
  plot = fig4, width = 10, height = 6, dpi = 300
)
message("FIGURE 4 saved: figure4_uncertainty_ranges.png")

message("09_outputs.R: All outputs saved to outputs/tables/ and outputs/figures/")
