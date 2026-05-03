# =============================================================================
# 01_load_raw.R
# PURPOSE: Load all raw LSMS-ISA Tanzania NPS data files into memory
# INPUT:   data/raw/ — original World Bank files, do not rename
# OUTPUT:  named list `raw` — one entry per survey section
# =============================================================================

library(here)
library(tidyverse)
library(haven)
library(readxl)
library(data.table)

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

# NOTE: All file reads must live here. No raw file reads in any other script.
# If a new section is added, add its read_dta() call here and extend `raw` below.

# -----------------------------------------------------------------------------
# CROPS — plot and crop production data (ag_sec sections)
# Used in: clean/crops.R, impute/yield_gap.R
# LSMS-ISA Tanzania NPS Wave 4 agricultural sections
# -----------------------------------------------------------------------------

# Plot roster — farmer area estimates, GPS measures
raw_ag_sec_2a <- read_dta(here::here("data", "raw", "lsms", "ag_sec_2a.dta")) # long rainy season
raw_ag_sec_2b <- read_dta(here::here("data", "raw", "lsms", "ag_sec_2b.dta")) # short rainy season

# Plot details — soil quality, irrigation, water source
# Used in: impute/yield_gap.R (joining to pc for yield gap calculation)
raw_ag_sec_3a <- read_dta(here::here("data", "raw", "lsms", "ag_sec_3a.dta")) # long rainy season
raw_ag_sec_3b <- read_dta(here::here("data", "raw", "lsms", "ag_sec_3b.dta")) # short rainy season

# Crop harvest quantities, pre-harvest losses, harvest timing
raw_ag_sec_4a <- read_dta(here::here("data", "raw", "lsms", "ag_sec_4a.dta")) # long rainy season
raw_ag_sec_4b <- read_dta(here::here("data", "raw", "lsms", "ag_sec_4b.dta")) # short rainy season

# Tree/permanent crop harvest quantities
raw_ag_sec_6a <- read_dta(here::here("data", "raw", "lsms", "ag_sec_6a.dta")) # fruit trees
raw_ag_sec_6b <- read_dta(here::here("data", "raw", "lsms", "ag_sec_6b.dta")) # permanent crops

# -----------------------------------------------------------------------------
# RECALL — household 7-day food consumption recall
# Used in: clean/recall.R
# LSMS-ISA Tanzania NPS Wave 4, Section J1
# -----------------------------------------------------------------------------

raw_hh_sec_j1 <- read_dta(here::here("data", "raw", "lsms", "hh_sec_j1.dta"))

# -----------------------------------------------------------------------------
# AG PRODUCE — agricultural product processing and by-products
# Used in: clean/ag_produce.R
# LSMS-ISA Tanzania NPS Wave 4, Section 10
# -----------------------------------------------------------------------------

raw_ag_sec_10 <- read_dta(here::here("data", "raw", "lsms", "ag_sec_10.dta"))

# -----------------------------------------------------------------------------
# ANIMALS — livestock ownership, slaughter, feed practices, fishery
# Used in: clean/animals.R, impute/animals.R
# LSMS-ISA Tanzania NPS Wave 4, livestock sections
# -----------------------------------------------------------------------------

raw_lf_sec_02 <- read_dta(here::here("data", "raw", "lsms", "lf_sec_02.dta")) # livestock ownership & slaughter
raw_lf_sec_04 <- read_dta(here::here("data", "raw", "lsms", "lf_sec_04.dta")) # livestock feeding practices
raw_lf_sec_12 <- read_dta(here::here("data", "raw", "lsms", "lf_sec_12.dta")) # fishery

# 🚩 FLAG BOUNDARY: lf_sec_a (livestock identifiers) read in 03_Animals.Rmd with eval=FALSE;
# loading omitted here as downstream code does not use it in the active pipeline.
# Review if identifiers become needed for exclusion or linking in stage 3.

# -----------------------------------------------------------------------------
# ANIMAL PRODUCTS — hides, eggs, and other livestock products
# Used in: clean/animal_products.R
# LSMS-ISA Tanzania NPS Wave 4, Section 8
# -----------------------------------------------------------------------------

raw_lf_sec_08 <- read_dta(here::here("data", "raw", "lsms", "lf_sec_08.dta"))

# -----------------------------------------------------------------------------
# MILK — milk production, destinations, and processing
# Used in: clean/milk.R
# LSMS-ISA Tanzania NPS Wave 4, Section 6
# -----------------------------------------------------------------------------

raw_lf_sec_06 <- read_dta(here::here("data", "raw", "lsms", "lf_sec_06.dta"))

# -----------------------------------------------------------------------------
# DESTINATIONS — crop and tree product disposition (sales, storage, consumption)
# Used in: clean/destinations.R
# LSMS-ISA Tanzania NPS Wave 4, Sections 5a/5b (crops), 7a/7b (trees)
# -----------------------------------------------------------------------------

raw_ag_sec_5a <- read_dta(here::here("data", "raw", "lsms", "ag_sec_5a.dta")) # crop disposition long rainy
raw_ag_sec_5b <- read_dta(here::here("data", "raw", "lsms", "ag_sec_5b.dta")) # crop disposition short rainy
raw_ag_sec_7a <- read_dta(here::here("data", "raw", "lsms", "ag_sec_7a.dta")) # tree disposition fruit season
raw_ag_sec_7b <- read_dta(here::here("data", "raw", "lsms", "ag_sec_7b.dta")) # tree disposition permanent

# -----------------------------------------------------------------------------
# REFERENCE DATA — external methodology inputs (not LSMS survey sections)
# Used in: impute/yield_gap.R, impute/animals.R, clean/ag_produce.R,
#          clean/destinations.R (via 06a_Residue logic)
# -----------------------------------------------------------------------------

# 🚩 FLAG ASSUMPTION: Reference files loaded here for central path management.
# These are external data sources, not household survey data.
# If reference management is formalised, move to a dedicated ref/ loader.

ref_gyga     <- read_excel(here::here("data", "reference", "GygaTanzania-2.xlsx"), sheet = "Country")
# Source: Global Yield Gap Atlas (GYGA) — Tanzania country data
# URL: https://www.yieldgap.org/tanzania
# Used for: potential yield (YP) in impute/yield_gap.R

ref_breakdown <- read_excel(here::here("data", "reference", "breakdown.xlsx"), sheet = "conv")
# Source: @Hal.2020; @beefyieldguide; @lambyieldguide; @Alexander.2016; @Opio.2013 p.171
# Used for: carcass component fractions (meat, offal, hides, waste) in impute/animals.R

ref_rpr       <- fread(here::here("data", "reference", "RPR_updated_long.csv"))
# Source: FAO FAOSTAT residue:production ratios
# Used for: crop residue estimation in clean/destinations.R (06a_Residue logic)

ref_cropmap   <- fread(here::here("data", "reference", "residuematch.csv"), header = TRUE)
# Fuzzy crop name mapping: survey cropid → FAOSTAT Item name
# Used for: joining RPR ratios to survey crops in clean/destinations.R

# =============================================================================
# OUTPUT: Named list — one entry per survey section
# =============================================================================

raw <- list(
  # --- LSMS-ISA survey sections ---
  crops = list(
    ag_sec_2a = raw_ag_sec_2a,  # plot roster, long rainy
    ag_sec_2b = raw_ag_sec_2b,  # plot roster, short rainy
    ag_sec_3a = raw_ag_sec_3a,  # plot details, long rainy
    ag_sec_3b = raw_ag_sec_3b,  # plot details, short rainy
    ag_sec_4a = raw_ag_sec_4a,  # crop harvest, long rainy
    ag_sec_4b = raw_ag_sec_4b,  # crop harvest, short rainy
    ag_sec_6a = raw_ag_sec_6a,  # tree/fruit harvest
    ag_sec_6b = raw_ag_sec_6b   # permanent crop harvest
  ),
  recall = list(
    hh_sec_j1 = raw_hh_sec_j1
  ),
  ag_produce = list(
    ag_sec_10 = raw_ag_sec_10
  ),
  animals = list(
    lf_sec_02 = raw_lf_sec_02,  # ownership & slaughter
    lf_sec_04 = raw_lf_sec_04,  # feeding practices
    lf_sec_12 = raw_lf_sec_12   # fishery
  ),
  animal_products = list(
    lf_sec_08 = raw_lf_sec_08
  ),
  milk = list(
    lf_sec_06 = raw_lf_sec_06
  ),
  destinations = list(
    ag_sec_5a = raw_ag_sec_5a,
    ag_sec_5b = raw_ag_sec_5b,
    ag_sec_7a = raw_ag_sec_7a,
    ag_sec_7b = raw_ag_sec_7b
  ),
  # --- External reference data ---
  ref = list(
    gyga      = ref_gyga,
    breakdown = ref_breakdown,
    rpr       = ref_rpr,
    cropmap   = ref_cropmap
  )
)

message("01_load_raw.R: all raw data loaded successfully. Sections: ",
        paste(names(raw), collapse = ", "))
