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
# Population Sankey built inline below using networkD3.
# utils/mfa_flow.R provides the canonical wrappers for Sankey construction:
#   - mfa_flow_type(data_list)    — population-level flow (sums across HH before mfafun)
#   - mfa_flow_hh(data_list, id)  — single-household flow (for project 03 individual profiles)
#   - mfa_flow_all_hh(data_list)  — named list of flows for all HH (project 03 clustering input)
# To rebuild this Sankey via mfa_flow_type(), load the mfa_list (crops/meat/ap) and call:
#   flow_data <- mfa_flow_type(mfa_list)
#   sankey(flow_data)
# =============================================================================

# FIGURE 1: Material flow Sankey — absolute kg from households
# Using networkD3 for summary-level Sankey (source/target/value format)
# ggalluvial requires row-per-observation format — not appropriate here

library(networkD3)
library(htmlwidgets)

# Build flow data in absolute kg
sankey_flows <- bind_rows(
  households |>
    summarise(
      sold     = sum(dest_sold_kg,     na.rm = TRUE),
      consumed = sum(dest_consumed_kg, na.rm = TRUE),
      stored   = sum(dest_stored_kg,   na.rm = TRUE),
      feed     = sum(dest_feed_kg,     na.rm = TRUE)
    ) |>
    pivot_longer(everything(), names_to = "target", values_to = "value") |>
    mutate(source = "Crops"),
  households |>
    summarise(
      sold     = sum(milk_sold_kg,     na.rm = TRUE),
      consumed = sum(milk_consumed_kg, na.rm = TRUE)
    ) |>
    pivot_longer(everything(), names_to = "target", values_to = "value") |>
    mutate(source = "Milk"),
  households |>
    summarise(
      sold     = sum(egg_sold_kg,      na.rm = TRUE),
      consumed = sum(egg_produced_kg - egg_sold_kg, na.rm = TRUE)
    ) |>
    pivot_longer(everything(), names_to = "target", values_to = "value") |>
    mutate(source = "Eggs")
) |>
  filter(value > 0) |>
  mutate(target = paste0(target, " "))   # avoid node name collision (source == target label)

# Build node list
nodes <- data.frame(name = unique(c(sankey_flows$source, sankey_flows$target)))
sankey_flows <- sankey_flows |>
  mutate(
    IDsource = match(source, nodes$name) - 1,
    IDtarget = match(target, nodes$name) - 1
  )

fig1_sankey <- sankeyNetwork(
  Links   = sankey_flows,
  Nodes   = nodes,
  Source  = "IDsource",
  Target  = "IDtarget",
  Value   = "value",
  NodeID  = "name",
  units   = "kg",
  fontSize = 12,
  nodeWidth = 20
)

# Save as PNG via webshot (requires webshot2 + chromium)
fig1_path <- here::here("01-smallholder-material-flow", "outputs", "figures", "figure1_flow_sankey.html")
saveWidget(fig1_sankey, fig1_path, selfcontained = TRUE)

# 🚩 FLAG [TABLEAU]: export sankey_flows data for Tableau Public rebuild
# Tableau handles Sankey interactivity better than static PNG
write.csv(sankey_flows |> select(source, target, value),
          here::here("01-smallholder-material-flow", "outputs", "tables", "sankey_data.csv"),
          row.names = FALSE)

message("FIGURE 1 saved: figure1_flow_sankey.html (+ sankey_data.csv for Tableau)")

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
