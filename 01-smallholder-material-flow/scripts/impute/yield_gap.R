# =============================================================================
# impute/yield_gap.R
# PURPOSE: Estimate yield gaps using GYGA potential yields
# INPUT:   clean/pc.rds         — crop production with area (from clean/crops.R)
#          clean/plot_details.rds — irrigation/soil info (from clean/crops.R)
#          raw$ref$gyga          — GYGA Tanzania potential yield data (01_load_raw.R)
# OUTPUT:  data/processed/impute/yieldgaps.rds
#
# ASSUMPTIONS:
#   1. Potential yield (YP) source: Global Yield Gap Atlas (GYGA) Tanzania country data
#      URL: https://www.yieldgap.org/tanzania
#      Downloaded: 2024-01-19 (update comment if file re-downloaded)
#   2. Irrigated rice = "Irrigated rice" in GYGA; Rainfed crops = all other GYGA rows
#   3. Yield calculated as total_harvest (kg) / area_planted_new (ha), converted to t/ha
#   4. Yield gap (YG) = YP - yield (GYGA potential minus observed)
#   5. Negative YG (yield > potential) not excluded here — flag for review
#   6. Rainfed millet mapped to "finger millet" (GYGA "Rainfed millet") — bulrush millet
#      treated identically; no differentiation available in GYGA Tanzania data
#   7. Survey weighting NOT applied — use weighted estimates cautiously.
#      See: NOTE (backlog) in archived 01b_Yield_gap.Rmd; apply weigh() from
#      analysis/03-MCS_household.R once pipeline is stable.
#   8. Regional yield gap variation NOT implemented — country-level YP used throughout.
#      Regional sheet from GygaTanzania-2.xlsx available; treat as sensitivity analysis.
#
# =============================================================================

library(here)
library(tidyverse)
library(data.table)

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "impute"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# STEP 1: MAP GYGA CROP NAMES TO LSMS SURVEY CROPIDS
# =============================================================================

gyga_raw <- raw$ref$gyga

# 🚩 FLAG ASSUMPTION: Crop name mapping below derived from GYGA taxonomy.
# "Rainfed millet" treated as "finger millet" — bulrush millet not separately
# represented in GYGA Tanzania data. Potential yield may differ.
gyga <- gyga_raw %>%
  mutate(cropid = case_when(
    CROP == "Irrigated rice"      ~ "paddy",
    CROP == "Rainfed chickpea"    ~ "chickpea",
    CROP == "Rainfed common bean" ~ "bean",
    CROP == "Rainfed cowpea"      ~ "cowpea",
    CROP == "Rainfed groundnut"   ~ "groundnut",
    CROP == "Rainfed maize"       ~ "maize",
    CROP == "Rainfed millet"      ~ "finger millet",
    CROP == "Rainfed pigeonpea"   ~ "pigeon pea",
    CROP == "Rainfed rice"        ~ "paddy",
    CROP == "Rainfed sorghum"     ~ "sorghum",
    CROP == "Rainfed wheat"       ~ "wheat"
  ))

# =============================================================================
# STEP 2: LOAD CLEANED CROP DATA
# =============================================================================

pc          <- readRDS(here::here("data", "processed", "clean", "pc.rds")) %>% clear.labels()
plots_full  <- readRDS(here::here("data", "processed", "clean", "plot_details.rds"))

# =============================================================================
# STEP 3: IRRIGATED SAMPLE
# Plots reporting irrigation joined to GYGA irrigated rice YP
# =============================================================================

ref_irr <- gyga %>% filter(CROP == "Irrigated rice")

irrigated <- plots_full %>%
  filter(irrigated == "yes") %>%
  clear.labels() %>%
  left_join(pc,       by = c("y4_hhid", "plotnum")) %>%
  left_join(ref_irr,  by = "cropid") %>%
  mutate(
    yield      = (total_harvest / 1000) / area_planted_new,  # t/ha
    yield_gap  = YP - yield                                   # t/ha gap
  )

yg_irrigated <- irrigated %>%
  mutate(
    harvest_t = total_harvest / 1000,
    yield     = harvest_t / area_planted_new
  ) %>%
  select(y4_hhid, type, cropid, plotnum, preharvest_losses, loss_cause,
         area_planted_new, total_harvest, yield, YP, lessharvest) %>%
  mutate(
    YG       = YP - yield,
    irr_type = "irrigated"
  )

# 🚩 FLAG EXCLUSION: Irrigated sample includes only plots with irrigated == "yes".
# Plots missing irrigation status treated as rainfed.
# Profile count in 05_exclusions_audit.R.

# =============================================================================
# STEP 4: RAINFED SAMPLE
# All non-irrigated plots joined to GYGA rainfed crop YP
# =============================================================================

ref_rain <- gyga %>% filter(CROP != "Irrigated rice")

rainfed <- plots_full %>%
  filter(irrigated == "no") %>%
  clear.labels() %>%
  right_join(pc,       by = c("y4_hhid", "plotnum")) %>%
  left_join(ref_rain,  by = "cropid") %>%
  mutate(
    yield      = (total_harvest / 1000) / area_planted_new,
    yield_gap  = YP - yield
  )

yg_rainfed <- rainfed %>%
  mutate(
    harvest_t = total_harvest / 1000,
    yield     = harvest_t / area_planted_new
  ) %>%
  select(y4_hhid, type, cropid, plotnum, preharvest_losses, loss_cause,
         area_planted_new, total_harvest, yield, YP, lessharvest) %>%
  mutate(
    YG       = YP - yield,
    irr_type = "rainfed"
  )

# 🚩 FLAG ASSUMPTION: Crops with no GYGA match (YP == NA) will have YG == NA.
# These crops are not excluded — NA propagates downstream.
# Decision required before stage 3: impute YP from regional/continental data,
# or drop crop from yield gap analysis entirely.

# =============================================================================
# STEP 5: COMBINE AND SAVE
# =============================================================================

yieldgaps <- bind_rows(yg_rainfed, yg_irrigated)

# Diagnostic: crops with no YP match
no_yp <- yieldgaps %>% filter(is.na(YP)) %>% distinct(cropid) %>% arrange(cropid)
if (nrow(no_yp) > 0) {
  # 🚩 FLAG ASSUMPTION: The following crops have no GYGA potential yield — YG = NA.
  message("impute/yield_gap.R: ", nrow(no_yp), " crop(s) with no GYGA YP match:")
  print(no_yp)
}

# 🚩 FLAG ASSUMPTION: Negative yield gaps (observed yield > GYGA potential)
# are not removed here. They may reflect data issues, exceptional local conditions,
# or GYGA YP underestimation for Tanzania. Flag for sensitivity analysis.
neg_yg <- yieldgaps %>% filter(!is.na(YG) & YG < 0) %>% nrow()
if (neg_yg > 0) {
  message("impute/yield_gap.R: ", neg_yg, " plot(s) with negative yield gap (yield > YP).")
}

saveRDS(yieldgaps, here::here("data", "processed", "impute", "yieldgaps.rds"),
        compress = TRUE)

# CSV for QA / external review
readr::write_csv(
  yieldgaps %>% clear.labels(),
  here::here("data", "processed", "impute", "yieldgaps.csv")
)

message("impute/yield_gap.R: yield gaps estimated and saved.")
