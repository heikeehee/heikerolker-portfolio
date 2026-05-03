# =============================================================================
# clean/destinations.R
# PURPOSE: Clean crop and tree product disposition survey sections;
#          estimate crop residue flows
# INPUT:   raw$destinations from 01_load_raw.R
#          raw$ref$rpr, raw$ref$cropmap (via 01_load_raw.R)
#          clean/pc.rds, clean/pt.rds (from clean/crops.R)
# OUTPUT:  data/processed/clean/crop_disp.rds     (crop disposition, cleaned)
#          data/processed/clean/tree_disp.rds     (tree disposition, cleaned)
#          data/processed/clean/mass_crops.rds    (crops + disposition)
#          data/processed/clean/mass_trees.rds    (trees + disposition)
#          data/processed/clean/mass_allcrops.rds (crops + trees combined)
#          data/processed/clean/excl_crops.csv    (exclusion flags, crops)
#          data/processed/clean/excl_trees.csv    (exclusion flags, trees)
#          data/processed/clean/mass_residue.rds  (crop residue flows)
# SECTION: ag_sec_5a/5b (crop disposition), ag_sec_7a/7b (tree disposition)
# =============================================================================

library(here)
library(tidyverse)
library(data.table)

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "clean"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# SECTION 1: CROP DISPOSITION (ag_sec_5a / ag_sec_5b)
# =============================================================================

ag_sec_5a <- raw$destinations$ag_sec_5a  # long rainy season
ag_sec_5b <- raw$destinations$ag_sec_5b  # short rainy season

long  <- prep(ag_sec_5a, season = "long")
short <- ag_sec_5b %>%
  prep("short") %>%
  strip_colnames("5b", "5a")

labs <- prep_labs(short)
disp <- long %>% bind_dt(short)

setnames(disp, "zaocode", "cropid")
disp <- disp %>% clean_names(list = crops_list, "cropid")

label(disp) <- as.list(labs[match(names(disp), names(labs))])

crop_disp <- upData(disp,
  rename = .q(
    ag5a_01  = sale,
    ag5a_02  = sold,
    ag5a_03  = value_sale,
    ag5a_04  = b1,
    ag5a_05  = soldb1,
    ag5a_06  = value_b1,
    ag5a_08  = n_int1,
    ag5a_11  = b2,
    ag5a_12  = soldb2,
    ag5a_13  = value_b2,
    ag5a_15  = n_int2,
    ag5a_23  = storage,
    ag5a_24  = stored,
    ag5a_28  = storage_purpose,
    ag5a_29  = lost,
    ag5a_30  = loss_cause,
    ag5a_32  = value_losses,
    ag5a_32a = consumed,
    ag5a_32b = seed,
    ag5a_32c = payment,
    ag5a_32d = gifts,
    ag5a_32e = feed,
    ag5a_33  = residue_use,
    ag5a_34  = residue,
    ag5a_35  = value_residue
  ),

  # Convert losses from percentage to fraction
  losses = ag5a_31 / 10,

  # Replace NA with structural 0 where gateway question was "no"
  # 🚩 FLAG EXCLUSION: Zeros applied where sale/storage/loss gateway == "no".
  # If a household answered "no" in error, these will under-count disposition.
  # Profile zero distributions in 05_exclusions_audit.R.
  sold    = ifelse(sale    == "no", 0, sold),
  soldb1  = ifelse(sale    == "no", 0, soldb1),
  soldb2  = ifelse(sale    == "no", 0, soldb2),
  stored  = ifelse(storage == "no", 0, stored),
  losses  = ifelse(lost    == "no", 0, losses),

  labels = .q(
    sale            = "Item was sold",
    sold            = "Quantity sold",
    soldb1          = "Quantity sold to main buyer",
    soldb2          = "Quantity sold to second largest buyer",
    storage         = "Item is being stored",
    stored          = "Quantity of item in storage",
    losses          = "Proportion of harvest lost post-harvest",
    loss_cause      = "Cause of ph losses",
    consumed        = "Quantity of item consumed",
    seed            = "Quantity stored for seed",
    payment         = "Quantity of item given as payment",
    gifts           = "Quantity of item given as gifts",
    feed            = "Quantity of item used as animal feed",
    residue         = "Quantity of residue sold"
  ),
  units = .q(
    sold       = kg, value_sales = `T shilling`,
    soldb1     = kg, value_b1    = `T shilling`,
    soldb2     = kg, value_b2    = `T shilling`,
    stored     = kg, losses      = percentage,
    consumed   = kg, seed        = kg,
    payment    = kg, gifts       = kg,
    feed       = kg, residue     = kg,
    value_residue = `T shilling`
  )
)

# 🚩 FLAG ASSUMPTION: Household 8659-001, maize consumed := 480.
# Clear data entry error — value was implausibly large. Verified against raw data.
# Hardcoded by design. Flag for re-review if raw data changes.
crop_disp[y4_hhid == "8659-001" & cropid == "maize", consumed := 480]

saveRDS(crop_disp,
        here::here("data", "processed", "clean", "crop_disp.rds"),
        compress = TRUE)

# =============================================================================
# SECTION 2: TREE DISPOSITION (ag_sec_7a / ag_sec_7b)
# =============================================================================

ag_sec_7a <- raw$destinations$ag_sec_7a  # fruit trees
ag_sec_7b <- raw$destinations$ag_sec_7b  # permanent crops

fruit <- prep(ag_sec_7a, season = "fruit")
perm  <- ag_sec_7b %>%
  prep("permanent") %>%
  strip_colnames("7b", "7a")

labs <- prep_labs(perm)
disp <- fruit %>% bind_dt(perm)

setnames(disp, "zaocode", "cropid")
disp <- disp %>% clean_names(list = crops_list, "cropid")

label(disp) <- as.list(labs[match(names(disp), names(labs))])

tree_disp <- upData(disp,
  rename = .q(
    ag7a_02 = sale,
    ag7a_03 = sold,
    ag7a_04 = value_sale,
    ag7a_07_1 = b1,
    ag7a_07_2 = b2,
    ag7a_08 = storage,
    ag7a_09 = stored,
    ag7a_13 = lost,
    ag7a_14 = loss_cause,
    ag7a_16 = value_losses,
    ag7a_17 = consumed,
    ag7a_18 = seed,
    ag7a_19 = payment,
    ag7a_20 = gifts,
    ag7a_21 = feed
  ),
  losses  = ag7a_15 / 10,
  sold    = ifelse(sale    == "no", 0, sold),
  stored  = ifelse(storage == "no", 0, stored),
  losses  = ifelse(lost    == "no", 0, losses),
  labels = .q(
    sale        = "Item was sold",
    sold        = "Quantity sold",
    b1          = "Buyer 1",
    b2          = "Buyer 2",
    storage     = "Item is being stored",
    stored      = "Quantity of item in storage",
    losses      = "Proportion of harvest lost post-harvest",
    loss_cause  = "Cause of ph losses",
    consumed    = "Quantity of item consumed",
    seed        = "Quantity stored for seed",
    payment     = "Quantity of item given as payment",
    gifts       = "Quantity of item given as gifts",
    feed        = "Quantity of item used as animal feed"
  ),
  units = .q(
    sold       = kg, value_sale    = `T Shilling`,
    stored     = kg, consumed      = kg,
    losses     = percentage,
    seed       = kg, payment       = kg,
    gifts      = kg, feed          = kg
  )
)

saveRDS(tree_disp,
        here::here("data", "processed", "clean", "tree_disp.rds"),
        compress = TRUE)

# =============================================================================
# SECTION 3: MERGE PRODUCTION WITH DISPOSITION
# 🚩 FLAG CROSS-SECTION: pc and pt from clean/crops.R required here.
# Run clean/crops.R before this section.
# =============================================================================

pc <- readRDS(here::here("data", "processed", "clean", "pc.rds"))
pt <- readRDS(here::here("data", "processed", "clean", "pt.rds"))

# --- Crops ---
pn_crops <- pc %>%
  select(y4_hhid, plotnum, cropid) %>%
  count(y4_hhid, cropid) %>%
  dplyr::rename(nplots = n)

pm_crops <- pc %>%
  group_by(y4_hhid, cropid) %>%
  summarise(mismatch = sum(mismatch), .groups = "drop") %>%
  setDT()

pn_crops <- merge(pn_crops, pm_crops, by = c("y4_hhid", "cropid"), all = TRUE)

chh <- pc[, .(
  harvest          = sum(quant_harvest),
  quant_unharvested = sum(quant_unharvested),
  total_harvest    = sum(total_harvest),
  area_planted     = sum(area_planted_new)
), by = .(y4_hhid, type, cropid)]

chh[, yield := total_harvest / area_planted]
chh <- merge(chh, pn_crops, by = c("y4_hhid", "cropid"), all = TRUE)

cd <- copy(crop_disp)
cd <- cd[, .(y4_hhid, type, cropid,
             sold, stored, losses, consumed, seed, payment, gifts, feed, residue)]
cd <- cd[, lapply(.SD, sm), .SDcols = is.numeric, by = .(y4_hhid, type, cropid)]

crops_merged <- merge(chh, cd, by = c("y4_hhid", "type", "cropid"), all = TRUE)

# Convert losses from fraction to kg
crops_merged <- upData(crops_merged,
  losses = losses * harvest,
  labels = .q(
    sold     = "Quantity sold", stored   = "Quantity of item in storage",
    consumed = "Quantity of item consumed", seed = "Quantity stored for seed",
    payment  = "Quantity of item given as payment", gifts = "Quantity of item given as gifts",
    feed     = "Quantity of item used as animal feed", losses  = "Quantity lost ph",
    residue  = "Quantity residue sold", harvest = "Annual quantity harvested",
    nplots   = "Number of plots crop planted on"
  ),
  units = .q(
    sold = kg, stored = kg, consumed = kg, losses = kg,
    seed = kg, payment = kg, gifts = kg, feed = kg, residue = kg
  ),
  drop = .q(area_planted, total_harvest, nplots, mismatch)
)

crops_merged[, smd := sold + stored + losses + consumed + payment + gifts + feed]
crops_merged[, smd := adlab(smd, "Sum of all disposition")]

saveRDS(crops_merged, here::here("data", "processed", "clean", "mass_crops.rds"),
        compress = TRUE)

# Exclusion flags: crops
crops_excl <- copy(crops_merged)
top2_fn    <- function(x) quantile(x, probs = 0.99, na.rm = TRUE)
crops_excl[, top := top2_fn(yield), by = cropid]

cropnums   <- crops_excl %>% group_by(cropid) %>% summarise(nums = n()) %>% setDT()
crops_excl <- cropnums[crops_excl, on = .(cropid)]
crops_excl[, yield := as.numeric(yield)]
crops_excl[, diff  := harvest - smd]
crops_excl[, diffp := diff * 100 / harvest]

crops_excl <- crops_excl[, excl := fcase(
  is.na(sold),         "Data missing",
  is.na(yield),        "Data missing",
  # 🚩 FLAG EXCLUSION: ±30% tolerance on disposition vs harvest.
  # Threshold not codebook-derived — chosen as pragmatic balance.
  # Profile sensitivity to threshold in 05_exclusions_audit.R.
  smd > harvest * 1.3, "Harvest insufficient",
  smd < harvest * 0.7, "Harvest unaccounted"
)]

ex_crops <- crops_excl %>%
  clear.labels() %>%
  filter(is.na(excl)) %>%
  filter_at(vars(sold:residue), any_vars(. > harvest * 1.2)) %>%
  mutate(excl = "Data inconsistent")

crops_excl    <- crops_excl[!ex_crops, on = .(y4_hhid, cropid)]
crops_excl    <- clear.labels(crops_excl)
excl_crops    <- bind_rows(crops_excl, ex_crops) %>% select(y4_hhid, item = cropid, excl)
write.csv(excl_crops, here::here("data", "processed", "clean", "excl_crops.csv"),
          row.names = FALSE)

# --- Trees ---
pn_trees <- pt %>%
  select(y4_hhid, plotnum, cropid) %>%
  count(y4_hhid, cropid) %>%
  dplyr::rename(nplots = n)

thh <- pt[, .(harvest = sum(harvest), ntrees = sum(ntrees)),
          by = .(y4_hhid, type, cropid)]
thh[, yield := harvest / ntrees]
thh <- merge(thh, pn_trees, by = c("y4_hhid", "cropid"), all = TRUE)

td <- copy(tree_disp)
td <- td[, .(y4_hhid, type, cropid,
             sold, stored, losses, consumed, seed, payment, gifts, feed)]
td <- td[, lapply(.SD, sm), .SDcols = is.numeric, by = .(y4_hhid, type, cropid)]

trees_merged <- merge(thh, td, by = c("y4_hhid", "type", "cropid"), all = TRUE)
trees_merged <- upData(trees_merged,
  losses = losses * harvest,
  labels = .q(
    sold = "Quantity sold", stored = "Quantity of item in storage",
    consumed = "Quantity of item consumed", seed = "Quantity stored for seed",
    payment = "Quantity of item given as payment", gifts = "Quantity of item given as gifts",
    feed = "Quantity of item used as animal feed", losses = "Quantity lost ph",
    harvest = "Annual quantity harvested", yield = "Yield (kg) per tree"
  ),
  units = .q(
    sold = kg, stored = kg, consumed = kg, losses = kg,
    seed = kg, payment = kg, gifts = kg, feed = kg
  )
)

trees_merged[, smd := sold + stored + losses + consumed + payment + gifts + feed]
trees_merged[, smd := adlab(smd, "Sum of all disposition")]

saveRDS(trees_merged, here::here("data", "processed", "clean", "mass_trees.rds"),
        compress = TRUE)

# Exclusion flags: trees
trees_excl <- copy(trees_merged)
trees_excl[, top := top2_fn(yield), by = cropid]
trees_excl[, `:=` (harvest = as.numeric(harvest), ntrees = as.numeric(ntrees))]

trees_excl <- trees_excl[, excl := fcase(
  is.na(sold),            "Incomplete",
  is.na(yield),           "Incomplete",
  ntrees == 0 & harvest > 0, "Non-match",
  smd > harvest * 1.3,    "Harvest insufficient",
  smd < harvest * 0.7,    "Harvest unaccounted"
)]

ex_trees   <- trees_excl %>%
  clear.labels() %>%
  filter(is.na(excl)) %>%
  filter_at(vars(sold:feed), any_vars(. > harvest * 1.2)) %>%
  mutate(excl = "Data inconsistent")

trees_excl <- trees_excl[!ex_trees, on = .(y4_hhid, cropid)]
excl_trees <- trees_excl %>% clear.labels() %>% bind_rows(ex_trees) %>%
  select(y4_hhid, item = cropid, excl)
write.csv(excl_trees, here::here("data", "processed", "clean", "excl_trees.csv"),
          row.names = FALSE)

# --- Combine crops + trees ---
ct <- crops_merged[, .(y4_hhid, type, cropid, harvest, sold, stored, seed, losses,
                       consumed, payment, gifts, feed, residue, smd)]
tc <- trees_merged[, .(y4_hhid, type, cropid, harvest, sold, stored, seed, losses,
                       consumed, payment, gifts, feed, smd)]
tc[, residue := NA]

tc <- upData(tc,
  harvest = as.integer(harvest),
  residue = as.integer(residue),
  labels  = .q(residue = "Quantity residue sold", harvest = "Annual quantity harvested"),
  units   = .q(residue = kg, harvest = kg)
)

allcrops <- rbindlist(list(ct, tc), fill = TRUE)
saveRDS(allcrops, here::here("data", "processed", "clean", "mass_allcrops.rds"),
        compress = TRUE)

# =============================================================================
# SECTION 4: CROP RESIDUE ESTIMATION (from 06a_Residue.Rmd)
# Uses RPR ratios from FAOSTAT and crop name mapping
# 🚩 FLAG CROSS-SECTION: Depends on mass_crops.rds → run after Section 3 above.
# =============================================================================

# Load inputs (from clean/ and reference data loaded in 01_load_raw.R)
residue  <- readRDS(here::here("data", "processed", "clean", "mass_crops.rds")) %>%
  select(y4_hhid, cropid, residue_use, residue, value_residue) %>%
  as.data.table()

prod <- readRDS(here::here("data", "processed", "clean", "pc.rds")) %>%
  select(cropid, y4_hhid, type, harvest = quant_harvest, total_harvest, quant_unharvested) %>%
  as.data.table()

# Join residue info to production
res_hh <- prod[residue, on = .(y4_hhid, cropid)]

# 🚩 FLAG EXCLUSION: Crops reporting "crop produces no residue" dropped.
# Confirm this is correct: is no-residue a survey category or a data-entry placeholder?
# Profile count in 05_exclusions_audit.R.
res_hh <- res_hh[residue_use != "crop produces no  residue"]

# Match to FAOSTAT RPR and DM ratios via crop name mapping
rpr_ref <- raw$ref$rpr %>%
  filter(AreaName == "Tanzania, United Rep. of")

cropmap    <- raw$ref$cropmap
res_hh_matched <- cropmap[res_hh, on = .(cropid)]
res_full       <- rpr_ref[res_hh_matched, on = .(Item)]

# Residue sold is recorded in DM
res_full[, residue_sold_DM := residue / Dry_matter]

# Estimate residue flows
# 🚩 FLAG ASSUMPTION: Residue:Production Ratio (RPR) and Dry Matter fraction
# from FAOSTAT are Tanzania-specific but country-level averages.
# Not plot- or crop-variety-specific. Flag for sensitivity analysis.
res_full[, `:=` (
  Residues_DM     = harvest * Dry_matter * RPR * UsedRes,                           # main estimate (DM)
  Residues_wet    = harvest * RPR * UsedRes,                                        # wet weight
  Residues_DM_alt = (harvest + quant_unharvested) * Dry_matter * RPR * UsedRes      # incl. unharvested
)]

# Output table
res_out <- res_full[, .(y4_hhid, cropid, type, harvest, Dry_matter, residue_use,
                        residue, Residues_DM, Residues_DM_alt, Residues_wet)]

# Mark residue allocated to animals
res_out[, grazing_res := ifelse(
  residue_use %in% c("for grazing own animals", "feeding own animals", "residue was left in field"),
  Residues_DM, 0
)]

saveRDS(res_out,  here::here("data", "processed", "clean", "mass_residue.rds"),
        compress = TRUE)
readr::write_csv(res_out, here::here("data", "processed", "clean", "mass_residue.csv"))

message("clean/destinations.R: all destination and residue outputs saved.")
