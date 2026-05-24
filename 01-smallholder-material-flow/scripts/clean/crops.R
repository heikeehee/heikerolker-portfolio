# =============================================================================
# clean/crops.R
# PURPOSE: Clean crops and plots survey sections
# INPUT:   raw$crops from 01_load_raw.R
# OUTPUT:  data/processed/01/clean/plots.rds
#          data/processed/01/clean/plots_stats.rds
#          data/processed/01/clean/crops.rds
#          data/processed/01/clean/trees.rds
#          data/processed/01/clean/pc.rds
#          data/processed/01/clean/pt.rds
#          data/processed/01/clean/prelost.rds
#          data/processed/01/clean/plot_details.rds
#          data/processed/01/clean/crops_prelost.rds
# NOTE:    Cleaning only. Standardise, preserve missingness, add flags.
#          Do not repair uncertain values here; those belong in impute/crops.R
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "01", "clean"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# SECTION 1: PLOTS (ag_sec_2a / ag_sec_2b)
# =============================================================================

ag_sec_2a <- raw$crops$ag_sec_2a
ag_sec_2b <- raw$crops$ag_sec_2b

long <- ag_sec_2a %>% setDT() %>% add_column(season = "long")
short <- ag_sec_2b %>% setDT() %>% add_column(season = "short")

colnames(short) <- colnames(long)

labs <- lapply(short, attr, "label")
labs <- unlist(labs, use.names = TRUE)

plots <- long %>% bind_rows(short) %>% clean_up()
plots <- zap_labels(plots)
label(plots) <- as.list(labs[match(names(plots), names(labs))])

plots <- upData(plots,
                rename = .q(
                  ag2a_04 = area,
                  ag2a_05 = plotnum_old,
                  ag2a_07 = measured,
                  ag2a_09 = gps_area,
                  ag2a_10 = weather
                ),
                area_ha = area * 0.40468564224,
                gps_area_ha = gps_area * 0.40468564224,
                labels = .q(
                  area        = "Farmers area estimate (acres)",
                  area_ha     = "Farmers area estimate (ha)",
                  gps_area_ha = "GPS area (ha)",
                  season      = "Harvesting season"
                ),
                units = .q(
                  area        = acres,
                  area_ha     = ha,
                  gps_area_ha = ha
                ),
                drop = .q(plotname, ag2a_06_1, ag2a_06_2, ag2a_06_3, ag2a_06_4)
)

# FLAG A1: GPS area is zero, which is treated as unusable for diagnostics
plots[, flag_gps_area_zero := fifelse(gps_area == 0, 1L, 0L)]
n_flag_gps_area_zero <- plots[flag_gps_area_zero == 1L, .N]
message("flag_gps_area_zero: ", n_flag_gps_area_zero, " rows where gps_area == 0")

saveRDS(plots, here::here("data", "processed", "01", "clean", "plots.rds"), compress = TRUE)

p <- plots[, .(y4_hhid, plotnum, area_ha, gps_area_ha)]

# Derived diagnostic only: composite plot size candidate
p[, plotsize_candidate := ifelse(is.na(gps_area_ha), area_ha, gps_area_ha)]

pn <- p %>% select(y4_hhid, plotnum) %>% count(y4_hhid) %>% dplyr::rename(nplots = n)

phh <- p %>% select(y4_hhid, plotnum, plotsize_candidate, area_ha, gps_area_ha) %>% unique()
phh[, land     := sum(plotsize_candidate, na.rm = TRUE), by = "y4_hhid"]
phh[, land_gps := sum(gps_area_ha, na.rm = TRUE), by = "y4_hhid"]
phh <- phh %>% select(y4_hhid, land, land_gps) %>% unique()
phh <- phh[pn, on = "y4_hhid"]

saveRDS(phh, here::here("data", "processed", "01", "clean", "plots_stats.rds"), compress = TRUE)

# =============================================================================
# SECTION 2: CROPS (ag_sec_4a / ag_sec_4b)
# =============================================================================

ag_sec_4a <- raw$crops$ag_sec_4a
ag_sec_4b <- raw$crops$ag_sec_4b

long  <- prep(ag_sec_4a, season = "long")
short <- ag_sec_4b %>% prep("short") %>% strip_colnames("4b", "4a")

labs  <- prep_labs(short)
crops <- bind_dt(long, short)

setnames(crops, "zaocode", "cropid")
crops <- clean_names(crops, crops_list, "cropid")
label(crops) <- as.list(labs[match(names(crops), names(labs))])
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
                area_planted = case_when(
                  ag4a_02 == "1/4" ~ 0.25,
                  ag4a_02 == "1/2" ~ 0.5,
                  ag4a_02 == "3/4" ~ 0.75,
                  ag4a_01 == "yes" ~ 1
                ),
                loss_cause = ifelse(preharvest_losses == "no" & is.na(loss_cause), "no loss", loss_cause),
                area_harvested_ha = area_harvested * 0.40468564224,
                labels = .q(
                  area_harvested    = "Estimate of area harvested (acres)",
                  area_harvested_ha = "Estimate of area harvested converted (ha)",
                  type              = "Food group",
                  area_planted      = "Estimate of proportion planted",
                  harvest_remain    = "Fraction of crop remaining to be harvested"
                ),
                units = .q(
                  area_harvested    = acres,
                  area_harvested_ha = ha,
                  quant_harvest     = kg,
                  value             = "T shilling",
                  area_planted      = percentage
                ),
                drop = .q(plotname, ag4a_01, ag4a_02)
)

# FLAGS: harvest logic and missingness
crops[harvested == "no"  & !is.na(quant_harvest), flag_harvest_contradiction := 1L]
crops[harvested == "yes" & is.na(quant_harvest),  flag_harvest_quantity_missing := 1L]
crops[is.na(harvested) & !is.na(plotnum) & !is.na(cropid), flag_harvest_missing := 1L]
crops[finished == "no" & is.na(harvest_remain) & !is.na(cropid), flag_harvest_remain_missing := 1L]

crops[, `:=`(
  flag_harvest_contradiction     = fifelse(is.na(flag_harvest_contradiction), 0L, flag_harvest_contradiction),
  flag_harvest_quantity_missing   = fifelse(is.na(flag_harvest_quantity_missing), 0L, flag_harvest_quantity_missing),
  flag_harvest_missing            = fifelse(is.na(flag_harvest_missing), 0L, flag_harvest_missing),
  flag_harvest_remain_missing     = fifelse(is.na(flag_harvest_remain_missing), 0L, flag_harvest_remain_missing)
)]

crops[harvested == "no" & !is.na(quant_harvest), flag_harvest_contradiction := 1L]
crops[harvested == "yes" & is.na(quant_harvest),  flag_harvest_quantity_missing := 1L]
crops[is.na(harvested) & !is.na(plotnum) & !is.na(cropid), flag_harvest_missing := 1L]
crops[finished == "no" & is.na(harvest_remain) & !is.na(cropid), flag_harvest_remain_missing := 1L]

message("flag_harvest_contradiction: ", crops[flag_harvest_contradiction == 1L, .N],
        " rows where harvested == 'no' but quant_harvest is not NA")
message("flag_harvest_quantity_missing: ", crops[flag_harvest_quantity_missing == 1L, .N],
        " rows where harvested == 'yes' but quant_harvest is NA")
message("flag_harvest_missing: ", crops[flag_harvest_missing == 1L, .N],
        " rows where harvested is NA")
message("flag_harvest_remain_missing: ", crops[flag_harvest_remain_missing == 1L, .N],
        " rows where finished == 'no' but harvest_remain is NA")

saveRDS(crops, here::here("data", "processed", "01", "clean", "crops.rds"), compress = TRUE)

crops_sub <- crops[, .(
  y4_hhid, plotnum, type, cropid,
  preharvest_losses, loss_cause,
  harvested, lessharvest, harvest_remain, quant_harvest,
  area_planted, area_harvested_ha
)]

pc <- p[crops_sub, on = c("y4_hhid", "plotnum")]

pc[, area_planted_ha := area_planted * plotsize_candidate]

# Derived diagnostics only, not replacements
pc[, area_harvested_alt := area_harvested_ha / area_ha * plotsize_candidate]
pc[, area_harvested_final_candidate := ifelse(
  lessharvest == "no" & is.na(harvest_remain),
  area_planted_ha,
  NA_real_
)]
pc[, area_harvested_com_candidate := ifelse(
  lessharvest == "no" & is.na(harvest_remain),
  area_planted_ha,
  area_harvested_alt
)]

# Flags
pc[, flag_area_planted_missing := fifelse(!is.na(plotnum) & is.na(area_planted), 1L, 0L)]
pc[, flag_plotnum_missing := fifelse(is.na(plotnum) & !is.na(cropid), 1L, 0L)]
pc[, flag_area_harvested_gt_plotsize := fifelse(area_harvested_com_candidate > plotsize_candidate, 1L, 0L)]
pc[, flag_quant_harvest_missing := fifelse(is.na(quant_harvest) & harvested == "yes", 1L, 0L)]

message("flag_area_planted_missing: ", pc[flag_area_planted_missing == 1L, .N],
        " records with missing area_planted on observed plot records")
message("flag_plotnum_missing: ", pc[flag_plotnum_missing == 1L, .N],
        " records with missing plotnum, check against household roster")
message("flag_area_harvested_gt_plotsize: ", pc[flag_area_harvested_gt_plotsize == 1L, .N],
        " records where harvested area candidate exceeds plotsize_candidate")
message("flag_quant_harvest_missing: ", pc[flag_quant_harvest_missing == 1L, .N],
        " records where quant_harvest is NA and harvest occurred")

pc <- upData(pc,
             labels = .q(
               plotsize_candidate         = "Composite plotsize candidate with gps where available",
               area_planted_ha            = "Estimate of area planted (ha)",
               area_harvested_final_candidate = "Area harvested candidate based on planted area assumption",
               area_harvested_alt         = "Area harvested based on proportional estimate",
               area_harvested_com_candidate = "Combined harvested area candidate",
               flag_area_planted_missing  = "Area planted missing on observed plot record",
               flag_plotnum_missing       = "Plot number missing",
               flag_area_harvested_gt_plotsize = "Area harvested candidate exceeds composite plotsize candidate",
               flag_quant_harvest_missing = "Harvest quantity missing on observed plot record",
               flag_harvest_contradiction  = "Harvested == no but quantity recorded",
               flag_harvest_quantity_missing = "Harvested == yes but quantity missing",
               flag_harvest_missing       = "Harvested response missing",
               flag_harvest_remain_missing = "Harvested == yes but harvest_remain missing"
             )
)

saveRDS(pc, here::here("data", "processed", "01", "clean", "pc.rds"), compress = TRUE)

crops_prelost <- crops %>% select(y4_hhid, cropid, type, plotnum, preharvest_losses, loss_cause)
saveRDS(crops_prelost, here::here("data", "processed", "01", "clean", "crops_prelost.rds"), compress = TRUE)

# =============================================================================
# SECTION 3: TREE CROPS (ag_sec_6a / ag_sec_6b)
# =============================================================================

ag_sec_6a <- raw$crops$ag_sec_6a
ag_sec_6b <- raw$crops$ag_sec_6b

fruit <- prep(ag_sec_6a, season = "fruit")
perm  <- ag_sec_6b %>% prep("permanent") %>% strip_colnames("6b", "6a")

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

trees_sub <- trees[, .(y4_hhid, plotnum, type, cropid, ntrees, harvest, pre_lost, loss_cause)]
pt <- p[trees_sub, on = c("y4_hhid", "plotnum")]
pt[, .q(area_ha, gps_area_ha) := NULL]
saveRDS(pt, here::here("data", "processed", "01", "clean", "pt.rds"), compress = TRUE)

cph <- pc[, .(
  y4_hhid, type, cropid, plotnum,
  pre_lost = preharvest_losses,
  loss_cause = as.character(loss_cause)
)]

tph <- pt[, .(
  y4_hhid, type, cropid, plotnum,
  pre_lost,
  loss_cause = as.character(loss_cause)
)]

prelost <- rbindlist(list(cph, tph), fill = TRUE)
prelost[, pre_lost := as.factor(pre_lost)]
prelost[, loss_cause := as.factor(loss_cause)]
saveRDS(prelost, here::here("data", "processed", "01", "clean", "prelost.rds"), compress = TRUE)

# =============================================================================
# SECTION 4: PLOT DETAILS (ag_sec_3a / ag_sec_3b)
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

message("flag_blank_plotnum_short: ", n_blank_plotnum,
        " short-season rows with blank or missing plotnum")
message("flag_short_code: ", n_flag_short_code,
        " short-season rows with ag3b_01b != 2 or missing, out of ", n_before)

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

stopifnot("Column count mismatch between seasons — check raw data structure" = ncol(short) == ncol(long))
colnames(short) <- colnames(long)

labs <- lapply(short, attr, "label")
labs <- unlist(labs, use.names = TRUE)

plots_full <- bind_rows(long, short) %>% clean_up()
plots_full <- zap_labels(plots_full)
label(plots_full) <- as.list(labs[match(names(plots_full), names(labs))])
saveRDS(plots_full, here::here("data", "processed", "01", "clean", "plot_details.rds"), compress = TRUE)

# =============================================================================
# FLAG SUMMARY
# =============================================================================
flag_summary_obj <- function(x, obj_name) {
  flag_cols <- names(x)[grepl("^flag_", names(x))]
  if (length(flag_cols) == 0) return(NULL)
  
  flag_summary <- data.table(
    flag = flag_cols,
    n = vapply(flag_cols, function(col) sum(x[[col]] == 1L, na.rm = TRUE), integer(1))
  )[order(-n)]
  
  message("----- Flag summary: ", obj_name, " -----")
  print(flag_summary)
  
  readr::write_csv(
    as.data.frame(flag_summary),
    here::here("data", "processed", "01", "clean", paste0(obj_name, "_flag_summary.csv"))
  )
  
  invisible(flag_summary)
}

flag_summary_obj(plots, "plots")
flag_summary_obj(crops, "crops")
flag_summary_obj(pc, "pc")
flag_summary_obj(trees, "trees")
flag_summary_obj(pt, "pt")
flag_summary_obj(prelost, "prelost")
flag_summary_obj(plots_full, "plot_details")