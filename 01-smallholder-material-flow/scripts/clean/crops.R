# =============================================================================
# clean/crops.R
# PURPOSE: Clean crops and plots survey sections
# INPUT:   raw$crops from 01_load_raw.R
# OUTPUT:  data/processed/clean/plots.rds
#          data/processed/clean/plots_stats.rds
#          data/processed/clean/crops.rds
#          data/processed/clean/trees.rds
#          data/processed/clean/pc.rds        (crops merged with plots)
#          data/processed/clean/pt.rds        (trees merged with plots)
#          data/processed/clean/prelost.rds   (pre-harvest losses)
#          data/processed/clean/plot_details.rds (soil/irrigation, for yield gap)
#          data/processed/clean/crops_prelost.rds
# SECTION: ag_sec_2a/2b (plot roster), ag_sec_3a/3b (plot details),
#          ag_sec_4a/4b (crop harvest), ag_sec_6a/6b (tree harvest)
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

# Ensure output directory exists
dir.create(here::here("data", "processed", "01", "clean"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# SECTION 1: PLOTS (ag_sec_2a / ag_sec_2b)
# Plot roster — farmer area estimates and GPS measurements
# =============================================================================

ag_sec_2a <- raw$crops$ag_sec_2a  # long rainy season
ag_sec_2b <- raw$crops$ag_sec_2b  # short rainy season

# Prepare each season for binding
long <- ag_sec_2a %>%
  setDT() %>%
  add_column(season = "long")

short <- ag_sec_2b %>%
  setDT() %>%
  add_column(season = "short")

# Align column names (short mirrors long structure after this)
colnames(short) <- colnames(long)

# Preserve labels for re-attachment after clean_up() strips them
labs <- lapply(short, attr, "label")
labs <- unlist(labs, use.names = TRUE)

# Bind and apply standard cleaning (strips labels, lowercases factors, etc.)
plots <- long %>%
  bind_rows(short) %>%
  clean_up()

plots <- zap_labels(plots)
label(plots) <- as.list(labs[match(names(plots), names(labs))])

# Rename and derive variables
plots <- upData(plots,
  rename = .q(
    ag2a_04 = area,
    ag2a_05 = plotnum_old,
    ag2a_07 = measured,
    ag2a_09 = gps_area,
    ag2a_10 = weather
  ),
  # Acres-to-hectares conversion — factor 0.40468564224
  # Source: standard international conversion; not codebook-specified.
  # Review if LSMS documentation uses a different factor.
  area_new     = area * 0.40468564224,
  gps_area_new = gps_area * 0.40468564224,

  # GPS readings of 0 are unreliable per LSMS team guidance — treat as NA.
  # This is the ONLY place GPS zeros are handled; the plotsize derivation
  # below relies on this and does not need a redundant != 0 check.
  gps_area_new = ifelse(gps_area == 0, NA_real_, gps_area_new),

  labels = .q(
    area         = 'Farmers area estimate (acres)',
    area_new     = 'Farmers area estimate (ha)',
    gps_area_new = 'GPS area (ha)',
    season       = 'Harvesting season'
  ),
  units = .q(
    area         = acres,
    area_new     = ha,
    gps_area_new = ha
  ),
  # Drop confidential or uninformative variables
  drop = .q(plotname, ag2a_06_1, ag2a_06_2, ag2a_06_3, ag2a_06_4)
)

saveRDS(plots, here::here("data", "processed", "01", "clean", "plots.rds"), compress = TRUE)

# --------------------------------------------------------------------------
# Derived: composite plot size (GPS preferred over farmer estimate)
# --------------------------------------------------------------------------
p <- plots[, .(y4_hhid, plotnum, area_new, gps_area_new)]

# Composite plotsize: GPS preferred over farmer estimate.
# GPS zeros already converted to NA above — no need for != 0 guard here.
p[, plotsize := ifelse(is.na(gps_area_new), area_new, gps_area_new)]
p[, plotsize := adlab(plotsize, "Reconciled plotsize (ha)")]

# --------------------------------------------------------------------------
# Plot statistics: total land per household
# --------------------------------------------------------------------------
pn <- p %>%
  select(y4_hhid, plotnum) %>%
  count(y4_hhid) %>%
  dplyr::rename(nplots = n)

phh <- p %>%
  select(y4_hhid, plotnum, plotsize, area_new, gps_area_new) %>%
  unique()

phh[, land     := sum(plotsize, na.rm = TRUE), by = "y4_hhid"]
phh[, land_gps := sum(gps_area_new, na.rm = TRUE), by = "y4_hhid"]
phh[, land     := adlab(land, "Sum of reconciled plotsizes (ha)")]
phh[, land_gps := adlab(land_gps, "Sum of gps plotsizes where available (ha)")]

phh <- phh %>% select(y4_hhid, land, land_gps) %>% unique()
phh <- phh[pn, on = "y4_hhid"]

saveRDS(phh, here::here("data", "processed", "01", "clean", "plots_stats.rds"), compress = TRUE)

# =============================================================================
# SECTION 2: CROPS (ag_sec_4a / ag_sec_4b)
# Annual crop harvest quantities, pre-harvest losses, area harvested
# =============================================================================

ag_sec_4a <- raw$crops$ag_sec_4a  # long rainy season
ag_sec_4b <- raw$crops$ag_sec_4b  # short rainy season

long  <- prep(ag_sec_4a, season = "long")
short <- ag_sec_4b %>%
  prep("short") %>%
  strip_colnames("4b", "4a")

labs  <- prep_labs(short)
crops <- bind_dt(long, short)

setnames(crops, "zaocode", "cropid")
crops <- clean_names(crops, crops_list, "cropid")

label(crops) <- as.list(labs[match(names(crops), names(labs))])

# =============================================================================
# E01: Harvest contradiction and missingness checks
# =============================================================================

# Flag 1: harvested == "no" but a quantity was recorded — enumerator error
crops[ag4a_19 == "no" & !is.na(ag4a_28),
      flag_harvest_contradiction := 1L]

n_contradiction <- sum(crops$flag_harvest_contradiction == 1L, na.rm = TRUE)
message("E01a flag_harvest_contradiction: ", n_contradiction,
        " records where harvested == 'no' but quant_harvest is not NA")

# Flag 2: harvested response itself is missing — cannot determine participation
crops[is.na(ag4a_19),
      flag_harvest_missing := 1L]

n_missing_harvest <- sum(crops$flag_harvest_missing == 1L, na.rm = TRUE)
message("E01b flag_harvest_missing: ", n_missing_harvest,
        " records where harvested is NA — participation status unknown")

crops <- upData(crops,
  rename = .q(
    ag4a_17 = preharvest_losses,
    ag4a_18 = loss_cause,
    ag4a_19 = harvested,
    ag4a_20 = noharvest_cause,
    ag4a_21 = area_harvested,
    ag4a_22 = lessharvest,
    ag4a_23 = lessharvest_cause,
    ag4a_24_1 = begin_harvest,
    ag4a_24_2 = end_harvest,
    ag4a_25 = finished,
    ag4a_27 = harvest_remain,
    ag4a_28 = quant_harvest,
    ag4a_29 = value
  ),
  # Proportion of plot planted with crop (fractional)
  area_planted = case_when(
    ag4a_02 == "1/4" ~ 0.25,
    ag4a_02 == "1/2" ~ 0.5,
    ag4a_02 == "3/4" ~ 0.75,
    ag4a_01 == "yes" ~ 1
  ),
  loss_cause = ifelse(preharvest_losses == "no" & is.na(loss_cause), "no loss", loss_cause),

  # Replace NA with structural 0 where no harvest occurred
  # EXCLUSION E01: harvest values set to 0 when harvested == "no"
  # Type: structural zero | missing data — FLAG
  # Profiled in: 05_exclusions_audit.R
  harvest_remain    = ifelse(finished == "yes", 0, harvest_remain),
  area_harvested    = ifelse(harvested == "no", 0, area_harvested),
  harvest_remain    = ifelse(harvested == "no", 0, harvest_remain),
  quant_harvest     = ifelse(harvested == "no", 0, quant_harvest),

  # Acres-to-hectares — same factor as plots. Not codebook-specified.
  area_harvested_new = area_harvested * 0.40468564224,

  labels = .q(
    area_harvested     = 'Estimate of area harvested (acres)',
    area_harvested_new = 'Estimate of area harvested converted (ha)',
    type               = 'Food group',
    area_planted       = "Estimate of proportion planted",
    harvest_remain     = "Fraction of crop remaining to be harvested"
  ),
  units = .q(
    area_harvested     = acres,
    area_harvested_new = ha,
    frac_remain        = percentage,
    quant_harvest      = kg,
    value              = 'T shilling',
    area_planted       = percentage
  ),
  drop = .q(plotname, ag4a_01, ag4a_02)
)

saveRDS(crops, here::here("data", "processed", "01", "clean", "crops.rds"), compress = TRUE)

# --------------------------------------------------------------------------
# Merge crops with plots to get per-crop area and yield
# --------------------------------------------------------------------------
crops_sub <- crops[, .(y4_hhid, plotnum, type, cropid,
  preharvest_losses, loss_cause,
  harvested, lessharvest, harvest_remain, quant_harvest,
  area_planted, area_harvested_new)]

# Left-inner join: all crop records, matched to plot sizes where available
pc <- p[crops_sub, on = c("y4_hhid", "plotnum")]

# Area planted as a fraction → convert to ha using composite plotsize
pc[, area_planted_new := area_planted * plotsize]

# Alternative area harvested: farmers estimate scaled by GPS/farmer ratio
pc[, area_harvested_alt := area_harvested_new / area_new * plotsize]

# Where harvest == all planted and no crops remain, area_harvested = area_planted
pc[, area_harvested_final := ifelse(lessharvest == "no" & is.na(harvest_remain),
                                    area_planted_new, NA)]
pc[, area_harvested_com   := ifelse(lessharvest == "no" & is.na(harvest_remain),
                                    area_planted_new, area_harvested_alt)]

# EXCLUSION E02: area_planted NA — replaced with area_harvested_new
# Type: missing data | profiled in 05_exclusions_audit.R
n_area_planted_na <- sum(is.na(pc$area_planted))
n_no_plotnum <- sum(is.na(pc$plotnum))

message("E02: ", n_area_planted_na, " NA area_planted values; ",
        n_no_plotnum, " records with NA plotnum")

# Only replace where plot exists and area_planted is missing
pc[, area_planted_new := fifelse(
  !is.na(plotnum) & is.na(area_planted),
  area_harvested_new,
  area_planted_new
)]

# total_harvest plausibility guard
# Flag where remaining harvest exceeds collected harvest by 3x — likely data error
pc[, flag_harvest_implausible := fifelse(
  harvest_remain > quant_harvest * 3 & quant_harvest > 0, 1L, 0L
)]

n_implausible <- sum(pc$flag_harvest_implausible == 1L, na.rm = TRUE)
message("flag_harvest_implausible: ", n_implausible,
        " records where harvest_remain > 3x quant_harvest")

pc[, total_harvest := harvest_remain + quant_harvest]

# EXCLUSION E03.1: area harvested exceeds composite plotsize — likely measurement error
pc[, mismatch_area := fifelse(area_harvested_com > plotsize, 1L, 0L)]

n_mismatch_area <- sum(pc$mismatch_area == 1L, na.rm = TRUE)
message("mismatch_area: ", n_mismatch_area, " records where area_harvested_com > plotsize")

# Separately: harvest quantity is missing (different problem — not an area issue)
pc[, mismatch_quant := fifelse(is.na(quant_harvest) & !is.na(plotnum), 1L, 0L)]

n_mismatch_quant <- sum(pc$mismatch_quant == 1L, na.rm = TRUE)
message("mismatch_quant: ", n_mismatch_quant, " records where quant_harvest is NA")

pc <- upData(pc,
  labels = .q(
    plotsize            = "Composite plotsize with gps where available",
    area_planted_new    = "Estimate of area planted (ha)",
    area_harvested_final = "Area harvested based on gps measure",
    area_harvested_alt  = "Area harvested based on proportional estimate",
    area_harvested_com  = "Area based on gps & proportional estimate",
    quant_unharvested   = "Imputed quantity of crop unharvested",
    total_harvest       = "Estimate of total harvest including remaining",
    area_remain         = "Area planted but not (yet) harvested",
    mismatch_area       = "Area harvested exceeds composite plotsize",
    mismatch_quant      = "Harvest quantity missing"
  ),
  units = .q(
    plotsize         = ha,
    area_planted_new = ha,
    quant_unharvested = kg,
    total_harvest    = kg,
    area_remain      = ha,
    area_harvested_com = ha
  )
)

saveRDS(pc, here::here("data", "processed", "01", "clean", "pc.rds"), compress = TRUE)

# --------------------------------------------------------------------------
# Pre-harvest losses (crops) — separate file for audit use
# --------------------------------------------------------------------------
crops_prelost <- crops %>%
  select(y4_hhid, cropid, type, plotnum, preharvest_losses, loss_cause)

saveRDS(crops_prelost, here::here("data", "processed", "01", "clean", "crops_prelost.rds"),
        compress = TRUE)

# =============================================================================
# SECTION 3: TREE CROPS (ag_sec_6a / ag_sec_6b)
# Fruit and permanent crop harvest quantities
# =============================================================================

ag_sec_6a <- raw$crops$ag_sec_6a  # fruit trees
ag_sec_6b <- raw$crops$ag_sec_6b  # permanent crops

fruit <- prep(ag_sec_6a, season = "fruit")
perm  <- ag_sec_6b %>%
  prep("permanent") %>%
  strip_colnames("6b", "6a")

labs  <- prep_labs(perm)
trees <- fruit %>% bind_dt(perm)

setnames(trees, "zaocode", "cropid")
trees <- trees %>% clean_names(list = crops_list, "cropid")

label(trees) <- as.list(labs[match(names(trees), names(labs))])

trees <- upData(trees,
  rename = .q(
    ag6a_02 = ntrees,
    ag6a_04 = newtrees,
    ag6a_09 = harvest,
    ag6a_10 = pre_lost,
    ag6a_11 = loss_cause
  ),
  labels = .q(
    ntrees   = "Number of trees on plot",
    newtrees = "Number of new trees planted in past 12 months",
    harvest  = "Quantity harvested"
  ),
  units = .q(
    harvest = kg
  )
)

saveRDS(trees, here::here("data", "processed", "01", "clean", "trees.rds"), compress = TRUE)

# Merge trees with plots
trees_sub <- trees[, .(y4_hhid, plotnum, type, cropid, ntrees, harvest, pre_lost, loss_cause)]
pt <- p[trees_sub, on = c("y4_hhid", "plotnum")]
pt[, .q(area_new, gps_area_new) := NULL]

saveRDS(pt, here::here("data", "processed", "01", "clean", "pt.rds"), compress = TRUE)

# --------------------------------------------------------------------------
# Pre-harvest losses: bind crops and trees
# --------------------------------------------------------------------------
cph <- pc[, .(
  y4_hhid,
  type,
  cropid,
  plotnum,
  pre_lost = preharvest_losses,
  loss_cause = as.character(loss_cause)
)]

tph <- pt[, .(
  y4_hhid,
  type,
  cropid,
  plotnum,
  pre_lost,
  loss_cause = as.character(loss_cause)
)]

prelost <- rbindlist(list(cph, tph), fill = TRUE)
prelost[, pre_lost   := as.factor(pre_lost)]
prelost[, loss_cause := as.factor(loss_cause)]

saveRDS(prelost, here::here("data", "processed", "01", "clean", "prelost.rds"), compress = TRUE)

# =============================================================================
# SECTION 4: PLOT DETAILS (ag_sec_3a / ag_sec_3b)
# Soil quality, irrigation, water source — used in impute/yield_gap.R
# Cleaning only: preserve raw missingness, standardize blanks to NA, flag
# exclusions instead of dropping early
# =============================================================================

ag_sec_3a <- raw$crops$ag_sec_3a
ag_sec_3b <- raw$crops$ag_sec_3b

long <- ag_sec_3a %>%
  setDT() %>%
  mutate(
    season = "long",
    flag_blank_plotnum = is.na(plotnum) | trimws(as.character(plotnum)) == "",
    flag_short_code = NA_integer_
  ) %>%
  mutate(across(where(is.character), ~ na_if(.x, ""))) %>%
  select(
    occ, y4_hhid, plotnum, season, flag_blank_plotnum, flag_short_code,
    main_crop  = ag3a_07_2,
    soil       = ag3a_10,
    soilqual   = ag3a_11,
    soiltest   = ag3a_12,
    erosion    = ag3a_13,
    irrigated  = ag3a_18,
    irrigation = ag3a_19,
    water      = ag3a_20,
    watersource = ag3a_21
  )

short_raw <- ag_sec_3b %>%
  setDT() %>%
  mutate(
    season = "short",
    flag_blank_plotnum = is.na(plotnum) | trimws(as.character(plotnum)) == "",
    flag_short_code = is.na(ag3b_01b) | ag3b_01b != 2
  ) %>%
  mutate(across(where(is.character), ~ na_if(.x, "")))

n_before <- nrow(short_raw)
n_blank_plotnum <- sum(short_raw$flag_blank_plotnum, na.rm = TRUE)
n_flag_short_code <- sum(short_raw$flag_short_code, na.rm = TRUE)

message("E03a: short-season blank plotnum rows = ", n_blank_plotnum)
message("E03b: short-season rows not coded as ag3b_01b == 2 = ", n_flag_short_code,
        " of ", n_before)

short <- short_raw %>%
  filter(ag3b_01b == 2) %>%
  select(!ag3b_01b) %>%
  select(
    occ, y4_hhid, plotnum, season, flag_blank_plotnum, flag_short_code,
    main_crop  = ag3b_07_2,
    soil       = ag3b_10,
    soilqual   = ag3b_11,
    soiltest   = ag3b_12,
    erosion    = ag3b_13,
    irrigated  = ag3b_18,
    irrigation = ag3b_19,
    water      = ag3b_20,
    watersource = ag3b_21
  )

stopifnot(
  "Column count mismatch between seasons — check raw data structure" =
    ncol(short) == ncol(long)
)

colnames(short) <- colnames(long)

labs <- lapply(short, attr, "label")
labs <- unlist(labs, use.names = TRUE)

plots_full <- bind_rows(long, short) %>%
  clean_up()

plots_full <- zap_labels(plots_full)
label(plots_full) <- as.list(labs[match(names(plots_full), names(labs))])

saveRDS(
  plots_full,
  here::here("data", "processed", "01", "clean", "plot_details.rds"),
  compress = TRUE
)