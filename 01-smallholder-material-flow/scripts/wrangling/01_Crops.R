## ----setup------------------------------------------------------------------------------------------------------
library(data.table)
library(haven)
library(here) # https://here.r-lib.org 
library(knitr)
library(Hmisc)
library(lubridate)
library(naniar)
library(dplyr)
library(tidyverse)
#knitr::opts_knit$set(root.dir = "03_MFA/Tanzania/wave4")

# load functions
# sys.source("1_scripts/functions1.R", envir = knitr::knit_global())


## ----plots hk---------------------------------------------------------------------------------------------------
# load data
ag_sec_2a <- read_dta(here::here("data", "raw", "ag_sec_2a.dta")) # --> long rainy
ag_sec_2b <- read_dta(here::here("data", "raw", "ag_sec_2b.dta")) # --> short rainy

# prepare for join
long <- ag_sec_2a %>% 
  setDT() %>% 
  add_column(season = "long")

short <- ag_sec_2b %>% 
  setDT() %>% 
  add_column(season = "short")

# match colnames
colnames(short) <- colnames(long)

# extract labels into named vector that can be matched to varnames 
labs <- lapply(short, attr, "label")
labs <- unlist(labs, use.names = T) # unlists into a named vector

# join & clean up
plots <- long %>% 
  bind_rows(short) %>% 
  clean_up() 

# needed?
plots <- zap_labels(plots)

# check labels
label(plots) 

# re-add labels: https://statisticsglobe.com/add-variable-labels-data-frame-r
label(plots) <- as.list(labs[match(names(plots), names(labs))])

contents(plots)


## ----plots naming-----------------------------------------------------------------------------------------------
# manually identify confidential variables
head(plots)

plots <- upData(plots,
                rename = .q(
                  ag2a_04 = area,
                  ag2a_05 = plotnum_old,
                  ag2a_07 = measured,
                  # ag2a_08 # not relevant enough
                  ag2a_09 = gps_area,
                  ag2a_10 = weather),
                area_new = area*0.40468564224, # convert area to hectars
                gps_area_new = gps_area * 0.40468564224, # convert area to hectars
                
                # based on LSMS team info, replace all gps=0 with NA
                gps_area_new = ifelse(gps_area==0, NA, gps_area_new),
                
                labels = .q(
                  area = 'Farmers area estimate (acres)',
                  area_new = 'Farmers area estimate (ha)',
                  gps_area_new = 'GPS area (ha)',
                  season = 'Harvesting season',
                ),
                units = .q(
                  area = acres,
                  area_new = ha,
                  gps_area_new = ha,
                ),
                # all confidential or containing unusable information
                drop = .q(plotname, ag2a_06_1, ag2a_03, ag2a_06_2, ag2a_06_3, ag2a_06_4) 
                )

saveRDS(plots, file = here::here("data", "processed", "01", "plots.RDS"), compress = TRUE)


## ----plots stats------------------------------------------------------------------------------------------------
# number of households without plot information



## ----plots------------------------------------------------------------------------------------------------------
# select relevant
p <- plots[, .(y4_hhid, plotnum, area_new, gps_area_new)] 

# add new area variables that uses gps when available and farmers' estimates when not
p[,plotsize := ifelse(gps_area_new !=0, gps_area_new, area_new)]
p[,plotsize := ifelse(is.na(gps_area_new), area_new, plotsize)]
p[,plotsize := adlab(plotsize, 'Reconciled plotsize (ha)')]

# save data -> purpose?
# saveRDS(p, file = "2_data/processed/plots_fin.RDS", compress = TRUE)


## ----plots hh---------------------------------------------------------------------------------------------------
# count plots per household
pn <- p %>% 
  select(y4_hhid, plotnum) %>% 
  count(y4_hhid) %>% 
  dplyr::rename(nplots = n)

# list all plots and size per household
phh <- p %>% 
  select(y4_hhid, plotnum, plotsize, area_new, gps_area_new) %>% 
  unique()

# calculate total land owned by household
phh[, land := sum(plotsize, na.rm = TRUE), by = "y4_hhid"] # give hhs with no plots a landsize of 0 -> allows determining how many do not own any land
phh[, land_gps := sum(gps_area_new, na.rm = TRUE), by = "y4_hhid"]
phh[,land := adlab(land, 'Sum of reconciled plotsizes (ha)')]
phh[,land_gps := adlab(land_gps, 'Sum of gps plotsizes where available (ha)')]

# reduce to households
phh <- phh %>% select(y4_hhid, land, land_gps) %>% unique()

# add number of plots owned per hh
phh <- phh[pn, on="y4_hhid"]

# group landownership into tertiles (no exclusions): small, medium, large --> in descriptive
# redo once exclusions are applied?
# NOTE (backlog): tertile grouping deferred — redo after exclusions applied
# quantile(phh$land, probs = seq(0,1,1/3), na.rm=TRUE)
# quantile(phh$land_gps, probs = seq(0,1,1/3), na.rm=TRUE)
# 
# phh <- phh %>% 
#   mutate(tertile = ntile(land, 3),
#          tertile_gps = ntile(land_gps, 3))

# save data
saveRDS(phh, here::here("data", "processed", "01", "plots_stats.RDS"), compress = T)


## ----crops hk---------------------------------------------------------------------------------------------------
# load data
ag_sec_4a <- read_dta(here::here("data", "raw", "ag_sec_4a.dta")) # --> long rainy
ag_sec_4b <- read_dta(here::here("data", "raw", "ag_sec_4b.dta")) # --> short rainy

# prep for join
long <- prep(ag_sec_4a, season = "long")
short <- ag_sec_4b %>% 
  prep("short") %>% 
  strip_colnames("4b", "4a")

# extract labels (short contains one additional variable)
labs <- prep_labs(short)

# join & clean
crops <- bind_dt(long, short)

# clean names of crops
setnames(crops,"zaocode","cropid") 
crops <- clean_names(crops, crops_list, "cropid")

# check labels
label(crops)

# add labels back
label(crops) <- as.list(labs[match(names(crops), names(labs))])

contents(crops)


## ----crops naming-----------------------------------------------------------------------------------------------
head(crops)

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
  area_planted = case_when( # proportion of plot planted with crop
    ag4a_02 == "1/4" ~ 0.25,
    ag4a_02 == "1/2" ~ 0.5,
    ag4a_02 == "3/4" ~ 0.75,
    ag4a_01 == "yes" ~ 1),

  # replace NA with 0 where true
  harvest_remain = ifelse(finished == "yes", 0, harvest_remain),
  area_harvested = ifelse(harvested == "no", 0, area_harvested),
  harvest_remain = ifelse(harvested == "no", 0, harvest_remain),
  quant_harvest = ifelse(harvested == "no", 0, quant_harvest),
  
  # area converted to hectars
  area_harvested_new = area_harvested * 0.40468564224,
  
  labels = .q(
    area_harvested = 'Estimate of area harvested (acres)',
    area_harvested_new = 'Estimate of area harvested converted (ha)',
    type = 'Food group',
    area_planted = "Estimate of proportion planted",
    harvest_remain = "Fraction of crop remaining to be harvested"
  ),
  units = .q(
    area_harvested = acres,
    area_harvested_new = ha,
    frac_remain = percentage,
    quant_harvest = kg,
    value = 'T shilling',
    area_planted = percentage
  ),
  drop = .q(plotname, ag4a_01, ag4a_02)
)

saveRDS(crops, file = here::here("data", "processed", "01", "crops.RDS"), compress = TRUE)


## ----crops stats------------------------------------------------------------------------------------------------



## ----crops plot-------------------------------------------------------------------------------------------------
# select relevant variables
c <- crops[, .(y4_hhid, plotnum, type, cropid, 
               # determine preharvest losses
               preharvest_losses, loss_cause,
               # remaining
               harvested, lessharvest, harvest_remain, quant_harvest, area_planted, area_harvested_new)]

# Keeps all ids in crops (left inner join) 
pc <- p[c, on=c("y4_hhid", "plotnum")]

# calculate area planted from proportion to ha (mostly based on gps measure)
pc[, area_planted_new := area_planted * plotsize]

# calculate area harvested as a proportion of the farmers plot size estimate and then use plotsize (mostly gps measure) to estimate the relative area harvested
pc[, area_harvested_alt := area_harvested_new/area_new*plotsize] # estimate harvested area from farmers estimate of area size and area harvested
# if harvest is the same as planted and no crops are remaining the area planted is equal to the area harvested (and the area planted is mostly derived from gps measure)
pc[, area_harvested_final := ifelse(lessharvest == "no" & is.na(harvest_remain), area_planted_new, NA)]
# use where area planted is the same as harvested or proportion of estimate
pc[, area_harvested_com := ifelse(lessharvest == "no" & is.na(harvest_remain), area_planted_new, area_harvested_alt)]

# 2 cases where area planted is not available, replace with farmers estimate of area harvested (no reason not to)
pc[, area_planted_new := ifelse(is.na(area_planted), area_harvested_new, area_planted_new)]

# if harvest is NOT the same as planted the area harvested is either
# taken from farmers' estimate OR
# calculate with farmers' estimate relative to their plotsize estimate
# pc[, area_harvested_final := ifelse(lessharvest == "yes", ?? , area_harvested_final)]

# quantify remaining harvest
# ifelse statement avoids NaNs
pc[, quant_unharvested := ifelse(harvest_remain == 0 & quant_harvest == 0, 0, harvest_remain *100/quant_harvest)]

# ASSUMPTION: quantify total harvest including remaining
# this is slightly flawed as one cannot know if the estimated remainder will be harvested, this approach has more acccuracy by using the gps measure of the plotsize
# on the other hand the estimate of area harvested is biased by farmers estimate of the plotsize AND harvest quantities
pc[, total_harvest := harvest_remain + quant_harvest]

pc[, area_remain := area_planted_new - area_harvested_new]
# NOTE (backlog): area loss estimation not accurately coded — retained for reference
# pc[, area_losses := ifelse(harvest_remain == 0 & lessharvest == "yes" & preharvest_losses == "yes", area_harvested_new - area_harvested_new, NA)] -> useless or not coded accurately

# tag entries for exclusion
pc[,mismatch := ifelse(area_harvested_com>plotsize, 1,0)] # 20% margin given some are estimates?

# tidy-up & naming
pc <- upData(pc,
  labels = .q(
    plotsize = "Composite plotsize with gps where available",
    area_planted_new = "Estimate of area planted (ha)",
    area_harvested_final = "Area harvested based on gps measure",
    area_harvested_alt = "Area harvested based on proportional estimate",
    area_harvested_com = "Area based on gps & proportional estimate",
    quant_unharvested = "Imputed quantity of crop unharvested",
    total_harvest = "Estimate of total harvest including remaining",
    yield = "Total yield (incl remaining) per area planted (kg/ha)",
    area_remain = "Area planted but not (yet) harvested",
    # area_losses = "Area planted with crops lost",
    mismatch = "Plotsize smaller than area harvested"
  
  ),
  units = .q(
    plotsize = ha,
    area_planted_new = ha,
    quant_unharvested = kg,
    total_harvest = kg,
    yield = kg/ha,
    area_remain = ha,
    # area_losses = ha,
    area_harvested_com = ha
  )
  )

# detemine what plot estimates to use primarily
# NOTE (backlog): diagnostic checks — retained for reference, not part of pipeline
# pc[area_harvested_new>plotsize] # estimate & mostly gps measure
# pc[area_harvested_alt>plotsize] # estimate as a proportion of gps measure & mostly gps measure
# pc[area_harvested_new>area_new] # both farmers estimate, should these be excluded?
# pc[area_harvested_new>gps_area_new] # estimtate & gps measure
# pc[area_harvested_com>plotsize] # assumes estimate of area planted somewhat more accurate than estimate of area harvested

miss_var_summary(pc)

# need removal or marking somehow
pc[is.na(quant_harvest)]

# mark where mismatch
pc[,mismatch := ifelse(is.na(quant_harvest), 1,mismatch)]

# save file: used in destination
saveRDS(pc, here::here("data", "processed", "01", "pc.RDS"), compress = TRUE)


## ----trees hk---------------------------------------------------------------------------------------------------
# same as for crops disp
ag_sec_6a <- read_dta(here::here("data", "raw", "ag_sec_6a.dta")) # --> fruit
ag_sec_6b <- read_dta(here::here("data", "raw", "ag_sec_6b.dta")) # --> permanent

# prep for join
fruit <- prep(ag_sec_6a, season = "fruit")
perm <- ag_sec_6b %>% 
  prep("permanent") %>% 
  strip_colnames("6b", "6a")

# extract labels (short contains one additional variable)
labs <- prep_labs(perm)

# join & clean
trees <- fruit %>% 
  bind_dt(perm)

setnames(trees,"zaocode","cropid") 
trees <- trees %>% clean_names(list = crops_list, "cropid")

label(trees) <- as.list(labs[match(names(trees), names(labs))])

contents(trees)


## ----trees naming-----------------------------------------------------------------------------------------------
trees <- upData(trees,
                rename = .q(
                  ag6a_02 = ntrees,
                  ag6a_04 = newtrees,
                  ag6a_09 = harvest,
                  ag6a_10 = pre_lost,
                  ag6a_11 = loss_cause
                ),

                labels = .q(
                  ntrees = "Number of trees on plot",
                  newtrees = "Number of new trees planted in past 12 months",
                  harvest = "Quantity harvested"
                ),
                units = .q(
                  harvest = kg,
                ))

head(trees)

# save file
saveRDS(trees, file = here::here("data", "processed", "01", "trees.RDS"), compress = TRUE)


## ----plots trees------------------------------------------------------------------------------------------------
# select relevant variables
trees_sub <- trees[,. (y4_hhid, plotnum, type, cropid, ntrees, harvest, pre_lost, loss_cause)]

# merge plots and trees
pt <- p[trees_sub, on=c("y4_hhid", "plotnum")]

# area not useful as contains plotsize and trees can be random/single
pt[, .q(area_new, gps_area_new) := NULL]
contents(pt)

saveRDS(pt, here::here("data", "processed", "01", "pt.RDS"), compress = T)


## ----plots trees stats------------------------------------------------------------------------------------------



## ----preharvest losses, eval=FALSE------------------------------------------------------------------------------
## prec <- pc[,.(y4_hhid, plotnum, type, cropid, plotsize, preharvest_losses, loss_cause, harvested, lessharvest)]


## ----trees & crops----------------------------------------------------------------------------------------------
# select vars
cph <- pc[,. (y4_hhid, type, cropid, plotnum, pre_lost = preharvest_losses, loss_cause)]
tph <- pt[, .(y4_hhid, type, cropid, plotnum, pre_lost, loss_cause)]

# bind them
prelost <- rbindlist(list(cph, tph), fill = TRUE)

prelost[,pre_lost := as.factor(pre_lost)]
prelost[,loss_cause := as.factor(loss_cause)]

summary(prelost)
saveRDS(prelost, here::here("data", "processed", "01", "prelost.RDS"), compress = TRUE)

