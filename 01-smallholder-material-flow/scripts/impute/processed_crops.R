# =============================================================================
# impute/processed_crops.R
# PURPOSE: Apply crop-specific extraction rates to split processing input
#          into product and byproduct quantities
# INPUT:   data/processed/clean/ag_produce.rds
# OUTPUT:  data/processed/imputed/processed_crops.rds
#
# ASSUMPTIONS: all extraction rates below are literature-derived.
# None are verifiable from LSMS-ISA survey data.
# Source column indicates literature reference where known.
# All rates flagged for sensitivity analysis — see backlog.md B05
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "imputed"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# STEP 1: EXTRACTION RATE TABLE
# =============================================================================

# --- EXTRACTION RATES ---
# Format: crop → product extraction rate (proportion of input mass)
# Byproduct rate = 1 − extraction_rate (mass balance closure)
#
# 🚩 FLAG [ASSUMPTION]: all rates below — confirm against FAO / local milling studies
# Sensitivity: backlog B05 — run MFA with ±10% extraction rate variation

extraction_rates <- tribble(
  ~crop,            ~product,   ~extraction_rate, ~byproduct,       ~source,
  "Maize",          "Flour",    0.72,             "Bran",           "FAO 1992 / Golob et al.",
  "Paddy",          "Rice",     0.65,             "Bran+husk",      "FAO 2003",
  "Sorghum",        "Flour",    0.75,             "Bran",           "assumed — flag",
  "Bulrush millet", "Flour",    0.75,             "Bran",           "assumed — flag",
  "Finger millet",  "Flour",    0.75,             "Bran",           "assumed — flag",
  "Sunflower",      "Oil",      0.35,             "Wet husk",       "FAO 2003",
  "Palm oil",       "Oil",      0.20,             "Wet husk",       "FAO 2003",
  "Sesame",         "Oil",      0.45,             "Residue",        "assumed — flag",
  "Cassava",        "Flour",    0.25,             "Other",          "FAO — fresh weight basis",
  "Sweet potatoes", "Flour",    0.25,             "Other",          "assumed — flag"
)

# 🚩 FLAG [ASSUMPTION]: crops not in this table have no processing split —
# treated as 100% product with 0% byproduct.
# These include: Coffee, Cashew nut — add rates if processing data present.

# =============================================================================
# STEP 2: LOAD CLEANED PROCESSED-CROP DATA
# =============================================================================

ag_produce <- zap_all(readRDS(here::here("data", "processed", "clean", "ag_produce.rds")))

# Diagnostic: unique crops in ag_produce
n_crops_raw <- n_distinct(ag_produce$cropid, na.rm = TRUE)
message("impute/processed_crops.R: ", n_crops_raw, " unique crop IDs in ag_produce.rds")

# =============================================================================
# STEP 3: DERIVE sent_to_processing_kg FROM ag_produce
# ag_produce records volume processed (new_input from clean/ag_produce.R).
# Treat `input` column as sent_to_processing_kg — the input quantity before processing.
# 🚩 FLAG [ASSUMPTION]: `input` field (ag10_05) assumed to equal volume sent to processing.
# Survey records volume processed, not volume sent — these may differ if transit losses occur.
# =============================================================================

ag_produce_proc <- ag_produce %>%
  filter(!is.na(cropid)) %>%
  select(y4_hhid, cropid, product, input) %>%
  rename(
    crop                 = cropid,
    sent_to_processing_kg = input
  ) %>%
  mutate(crop = str_to_title(crop))  # normalise case to match extraction_rates table

# =============================================================================
# STEP 4: JOIN EXTRACTION RATES AND APPLY PRODUCT / BYPRODUCT SPLIT
# =============================================================================

processed <- ag_produce_proc |>
  left_join(extraction_rates, by = "crop") |>
  mutate(
    product_kg   = sent_to_processing_kg * extraction_rate,
    byproduct_kg = sent_to_processing_kg * (1 - extraction_rate),
    # 🚩 FLAG [ASSUMPTION]: where extraction_rate is NA (crop not in table),
    # product_kg = sent_to_processing_kg, byproduct_kg = 0
    product_kg   = if_else(is.na(extraction_rate), sent_to_processing_kg, product_kg),
    byproduct_kg = if_else(is.na(extraction_rate), 0, byproduct_kg)
  )

# Diagnostic: crops that failed to match after str_to_title() normalisation
# A silent join miss here means 100% product assumption applies without warning
matched_crops   <- unique(processed$crop[!is.na(processed$extraction_rate)])
unmatched_crops <- unique(processed$crop[is.na(processed$extraction_rate) &
                                           !is.na(processed$sent_to_processing_kg)])
if (length(unmatched_crops) > 0) {
  message("impute/processed_crops.R: crops not matched to extraction_rates table ",
          "(treated as 100% product): ", paste(sort(unmatched_crops), collapse = ", "))
}
if (length(matched_crops) > 0) {
  message("impute/processed_crops.R: crops matched to extraction_rates table: ",
          paste(sort(matched_crops), collapse = ", "))
}

# =============================================================================
# STEP 5: DIAGNOSTICS
# =============================================================================

n_no_rate <- sum(is.na(processed$extraction_rate))
crops_no_rate <- processed |>
  filter(is.na(extraction_rate)) |>
  distinct(crop) |>
  arrange(crop) |>
  pull(crop)

message("impute/processed_crops.R: Crops with no extraction rate (treated as 100% product): ",
        n_no_rate, " rows")
if (length(crops_no_rate) > 0) {
  message("  Crops with no rate: ", paste(crops_no_rate, collapse = ", "))
}

# Cross-check: total mass balance (product + byproduct should equal sent_to_processing)
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

# =============================================================================
# STEP 6: SAVE
# =============================================================================

saveRDS(processed, here::here("data", "processed", "imputed", "processed_crops.rds"),
        compress = TRUE)

message("impute/processed_crops.R: processed crops imputed and saved. ",
        nrow(processed), " rows.")

# =============================================================================
# ASSUMPTIONS REGISTRY
# =============================================================================

# --- ASSUMPTION: Extraction rate table (all entries) ---
# Source: FAO 1992 / Golob et al. (maize); FAO 2003 (paddy, sunflower, palm oil);
#   assumed literature values (sorghum, millets, sesame, cassava, sweet potatoes)
# Value: See extraction_rates tribble above — proportion of input mass converted to main product.
# Sensitivity: backlog B05 — run MFA with ±10% extraction rate variation.
# 🚩 FLAG [ASSUMPTION]: All rates are literature-derived and unverifiable from LSMS-ISA survey data.
#   Tanzania-specific milling studies may produce different rates.

# --- ASSUMPTION: sent_to_processing_kg = input field (ag10_05) ---
# Source: LSMS NPS4 codebook — ag10_05 = "Input quantity before processing"
# Value: Input column used as proxy for volume sent to processing.
# Sensitivity: If transit losses between farm and processor are non-trivial,
#   true sent_to_processing_kg < input. No survey variable captures this difference.

# --- ASSUMPTION: Crops not in extraction_rates table treated as 100% product ---
# Source: conservative assumption (no alternative data available)
# Value: product_kg = sent_to_processing_kg, byproduct_kg = 0 for unmatched crops.
# Sensitivity: If Coffee, Cashew nut, or other unmatched crops have significant
#   byproduct fractions, their downstream mass balance will be overstated on the product side.
