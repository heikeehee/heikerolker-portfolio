# =============================================================================
# impute/processed_crops.R
# PURPOSE: Apply crop-specific extraction rates to split processing input
# into product and byproduct quantities
# INPUT: data/processed/01/impute/mass_agprod.rds
# OUTPUT: data/processed/01/impute/processed_crops.rds
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "01", "impute"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# TIER 1: EXTRACTION RATE TABLE
# =============================================================================

extraction_rates <- tribble(
  ~crop, ~product, ~extraction_rate, ~byproduct, ~source,
  "Maize", "Flour", 0.72, "Bran", "FAO 1992 / Golob et al.",
  "Paddy", "Rice", 0.65, "Bran+husk", "FAO 2003",
  "Sorghum", "Flour", 0.75, "Bran", "assumed — flag",
  "Bulrush millet", "Flour", 0.75, "Bran", "assumed — flag",
  "Finger millet", "Flour", 0.75, "Bran", "assumed — flag",
  "Sunflower", "Oil", 0.35, "Wet husk", "FAO 2003",
  "Palm oil", "Oil", 0.20, "Wet husk", "FAO 2003",
  "Sesame", "Oil", 0.45, "Residue", "assumed — flag",
  "Cassava", "Flour", 0.25, "Other", "FAO — fresh weight basis",
  "Sweet potatoes", "Flour", 0.25, "Other", "assumed — flag"
)

# Crops not in this table are treated as 100% product and 0% byproduct.

# =============================================================================
# TIER 2: APPLICATION AND DIAGNOSTICS
# =============================================================================

ag_produce_proc <- zap_all(readRDS(here::here("data", "processed", "01", "impute", "mass_agprod.rds")))

n_crops_raw <- n_distinct(ag_produce_proc$cropid, na.rm = TRUE)
message("impute/processed_crops.R: ", n_crops_raw, " unique crop IDs in mass_agprod.rds")

ag_produce_proc <- ag_produce_proc %>%
  filter(!is.na(cropid)) %>%
  select(y4_hhid, cropid, input) %>%
  distinct() %>%
  rename(
    crop = cropid,
    sent_to_processing_kg = input
  ) %>%
  mutate(crop = str_to_title(crop))

processed <- ag_produce_proc |>
  left_join(extraction_rates, by = "crop") |>
  mutate(
    product_kg = sent_to_processing_kg * extraction_rate,
    byproduct_kg = sent_to_processing_kg * (1 - extraction_rate),
    product_kg = if_else(is.na(extraction_rate), sent_to_processing_kg, product_kg),
    byproduct_kg = if_else(is.na(extraction_rate), 0, byproduct_kg)
  )

matched_crops <- unique(processed$crop[!is.na(processed$extraction_rate)])
unmatched_crops <- unique(processed$crop[is.na(processed$extraction_rate) & !is.na(processed$sent_to_processing_kg)])

if (length(unmatched_crops) > 0) {
  message("impute/processed_crops.R: crops not matched to extraction_rates table (treated as 100% product): ",
          paste(sort(unmatched_crops), collapse = ", "))
}

if (length(matched_crops) > 0) {
  message("impute/processed_crops.R: crops matched to extraction_rates table: ",
          paste(sort(matched_crops), collapse = ", "))
}

n_no_rate <- sum(is.na(processed$extraction_rate))
crops_no_rate <- processed |>
  filter(is.na(extraction_rate)) |>
  distinct(crop) |>
  arrange(crop) |>
  pull(crop)

message("impute/processed_crops.R: Crops with no extraction rate (treated as 100% product): ",
        n_no_rate, " rows")

if (length(crops_no_rate) > 0) {
  message(" Crops with no rate: ", paste(crops_no_rate, collapse = ", "))
}

processed <- processed |>
  mutate(
    mass_check = round(product_kg + byproduct_kg - sent_to_processing_kg, 4)
  )

n_imbalance <- sum(abs(processed$mass_check) > 1e-4, na.rm = TRUE)
if (n_imbalance > 0) {
  message("impute/processed_crops.R: WARNING — ", n_imbalance,
          " rows where product_kg + byproduct_kg ≠ sent_to_processing_kg")
} else {
  message("impute/processed_crops.R: mass balance check passed (product + byproduct = input)")
}

saveRDS(processed, here::here("data", "processed", "01", "impute", "processed_crops.rds"), compress = TRUE)

message("impute/processed_crops.R: processed crops imputed and saved. ", nrow(processed), " rows.")

# =============================================================================
# TIER 3 ACTIONS / TODO
# =============================================================================
# Tier 3 actions:
# - Sensitivity run with ±10% extraction rate variation.
# - Moisture/spillage loss deduction if you decide to add it.
# - Any crop-specific literature refinement that depends on external support rather than survey logic.
#
# Outstanding TODO:
# - Resolve the header path mismatch if any older comment still says clean/ag_produce.rds.
# - Promote unmatched-crop diagnostics to a formal flag column if you want them in the summary.
# - Align the assumptions registry with the MFA write-up.
# - Add Coffee and Cashew nut extraction rates if processing data are actually present.
# =============================================================================