## ------------------------------------------------------------------------------------------------------------
ag_filters <- read_csv("2_data/files/ag_filters.csv")


## ------------------------------------------------------------------------------------------------------------
library(readxl)
library(readr)
library(tidyverse)
library(data.table)
library(Hmisc)
# 1. Reference files ----
shortnames <- read_excel("2_data/reference/shortnames.xlsx")

# 2. Data files----
# general info
aFMe_summaries <- read_csv("2_data/final/aFMe_summaries.csv")
excl_3b <- read_csv("2_data/final/excl_3b.csv") %>% setDT()
# household info
hhA <- read_csv("2_data/files/hhA.csv") # place holder? general overview, household

# agricultural survey
produce_long <- readRDS("~/Library/CloudStorage/OneDrive-UniversityofBristol/03a_simpleMFA/2_data/final/produce_long.RDS") # from c3a

# recall data
recall_3b <- readRDS("2_data/final/recall_3b.RDS") # exclusions already removed

# 3. Shaping and functions----
# retain only included ag households
rm_excl <- function(df){
  incl <- excl_3b %>% 
    filter(status == "included") %>% 
    select(y4_hhid) %>% 
    unique()
  
  df %>% 
    inner_join(incl, by = "y4_hhid")
}

## ----name matching-------------------------------------------------------------------------------------------
# 4. Final files to use---- check if now accurate and complete
# adjust naming of food groups as required
LSMS_items_match <- read_csv("2_data/reference/LSMS_items_match2.csv") %>% 
  mutate(across(c(1:5), ~str_to_sentence(.x))) %>% 
  dplyr::rename(group = comment, itemcode = hh_product) 

# carrots are vegetables rather than starchy roots (conflict in matching)
  
# beverages may not be the most appropriate food group for agriculture
# animals are not identified as duplicates

saveRDS(LSMS_items_match, "2_data/final/LSMS_items_match_fin.RDS", compress = T)
LSMS_items_match %>% filter(is.na(group)) # mostly ignore


## ----production----------------------------------------------------------------------------------------------
# only ag items with food groups & key -  check comparison
ag_names <- LSMS_items_match %>% 
  select(item, group) %>% # to match on new name hh with hh file
  filter(!is.na(item)) %>% 
  unique() # no remaining duplicates


# production data to be used throughout
production <- produce_long %>% 
  filter(type != "Cashcrops" & subtype != "Other") %>% # not needed for this chapter; filters slaughtered animals..TBD
  select(!c(category:subtype)) %>% # just makes it more confusing, they should not be used for this chapter unless a clear plan emerges
  rm_excl() %>% # only included households
  left_join(select(hhA, y4_hhid, zone), by = "y4_hhid") %>%  # add zones
  left_join(ag_names, by = "item") %>% 
  # select(!c(smd, sold, uncertain)) %>% # could mess up the code somewhere...
  # mutate(
  #   group = ifelse(item == "Milk - small ruminants", "milk and dairy products", group),
  #   group = ifelse(item == "Calves meat" | item == "Calves offal", "meat, poultry and eggs", group)
  # )
  filter(!is.na(group)) %>%  # dogs etc.
  setDT()

# missing groups
production %>% filter(is.na(group)) %>% select(item) %>% unique() # fix manually not clear why group disappears

# count of items produced and consumed by group
production[, `:=` (n_cons = ifelse(consumed>0, 1, 0),
                   n_prod = ifelse(produced>0, 1, 0))]
production[, n_gr_cons := sum(n_cons), by = c("y4_hhid","group")]
production[, n_gr_prod := sum(n_prod), by = c("y4_hhid","group")]


saveRDS(production, "2_data/final/production.RDS", compress = T) # may not be necessary
fwrite(production,"2_data/final/production.csv") # not clear how this differs exactly from produce long...


## ------------------------------------------------------------------------------------------------------------
LSMS_items_match %>% select(itemcode) %>% unique() %>% filter(!is.na(itemcode)) # one missing?

hh_names <- LSMS_items_match %>% 
  select(itemcode, group) %>% # to match on new name ag with ag file
  filter(!is.na(itemcode)) %>% 
  filter(group!="slaughter") %>% 
  unique() %>%  # this should be 61 not 48
  arrange(itemcode)

# duplicates in vegetable and "other spices"
hh_names <- hh_names[-c(54),] # sweet potatoe cover

# recall data when not using bootstrapped results
sevendrecall <- readRDS("2_data/final/recall_3b_complete.RDS") %>%
  rm_excl() %>% 
  mutate(
    itemcode = str_to_sentence(itemcode)
  ) %>% 
  left_join(hh_names, by = "itemcode") 

saveRDS(sevendrecall, "2_data/final/sevendrecall.RDS", compress = T)

sevendrecall %>% filter(is.na(group)) %>% select(itemcode) %>% unique() # fixed in csv


## ------------------------------------------------------------------------------------------------------------
# Consumption as a proportion of production
production %>% 
  mutate(
    perc = consumed*100/produced
  ) %>% 
  group_by(group) %>%  # change to food group when available
  summarise(
    min = min(perc[consumed>0]),
    median = median(perc[consumed>0]),
    iqr = IQR(perc[consumed>0])
  )
# not fully valid for slaughtered animals which are not included in this dataframe anyways...



## ----afe consumption 1---------------------------------------------------------------------------------------
# aFMe_summaries$afehhmean <- rowMeans(subset(aFMe_summaries, select = c(afehh, afehhmax, afehhmin), na.rm = TRUE)) # may not be necessary and should be in a different file

# Annual AFE consumption for each household - x
# add ame & determine per capita annual consumption
prodcons <- production %>% 
  # left_join(foodgr, by = "product") %>% 
  left_join(select(aFMe_summaries, y4_hhid, hh_persons, starts_with("afe"))) %>% # define ame to use
  # estimate afe consumption 
  mutate(
    mo_cons = consumed/12, # household consumption per month
    annual_afe = consumed/afehh, # annual per AFE consumption of food group; recall value
    max_annual_afe = consumed/afehhmax, # min annual per AME consumption if all hh members are considered (independent of absence)
    min_annual_afe = consumed/afehhmin, # min average monthly consumption when considering all hh members
    mo_afe = annual_afe/12,    # average monthly AME consumption of food group
    mo_afemax = max_annual_afe/12,
    mo_afemin = min_annual_afe/12
    ) %>% 
  # select(!c(hh_persons:afehhmin)) %>% 
  left_join(ag_names)
# use to determine overlap/accuracy of source information, i.e. identify foods consumed based on foods produced

# mean annual consumption across afe estimates
prodcons$mean_afe <- rowMeans(subset(prodcons, select = c(annual_afe, min_annual_afe, max_annual_afe), na.rm = TRUE))
# average monthly consumption cross afe estimates
prodcons$mean_mo <- rowMeans(subset(prodcons, select = c(mo_afe, mo_afemax, mo_afemin), na.rm = TRUE))

prodcons %>% 
  group_by(zone, group) %>% 
  summarise(across(is.numeric, ~sum(.x)))

saveRDS(prodcons, "2_data/final/prodcons.RDS", compress = T)
write_csv(prodcons, "2_data/results/prodcons.csv")



prodconsflourish <- prodcons %>% 
  group_by(zone, y4_hhid, group) %>% 
  summarise(across(annual_afe:mean_mo, ~sm(.x))) %>% 
  setDT() %>% 
  select(y4_hhid, zone, group, contains("mo")) %>% 
  melt(id.vars = c("y4_hhid", "zone", "group"), variable.name = "estimate")
  
write_csv(prodconsflourish, "2_data/final/prodconsflourish.csv")


## ----afe consumption-----------------------------------------------------------------------------------------
# AFE overview and means
# 1) use mean across all values and standard deviation
# 2) use same as for bootstrap and show lower vs upper estimate (i.e., most AME vs fewest)

# Standard deviation for annual mean estimate
# number of items consumed per food group, indicates variety eaten from production
n_eat_ag <- prodcons %>% 
  mutate(
    item = ifelse(consumed>0,1,0)
  ) %>% 
  group_by(y4_hhid, group, zone) %>% 
  summarise(
    items = sum(item)
  ) %>% 
  mutate(
    group_cons = ifelse(items>0, 1, 0)
  ) %>% 
  filter(!is.na(group)) %>%  # should not be necessary
  # statistics for table
  ungroup() %>% 
  group_by(group, zone) %>% # for table 1 only group, zone too granular
  summarise(
    mean_eat = mean(items),
    max = max(items),
    sum = sum(group_cons) # number of households consuming food group
  )

# TABLE 1
prodcons %>% 
  group_by(group) %>% # check complete once files are synced properly
  summarise(
    # TBD
    # n_prod = length(produced[produced>0]), # number of producers
    n_cons = length(consumed[consumed>0]), # number of consumers - still double counts
    perc = n_cons*100/length(produced[produced>0]), # percentage of producers that consume
    N_perc = n_cons*100/nrow(excl_3b[status == "included"]), # percentage of all households that consume
    # n_obs = n(), # all households listed -> this only makes sense once the hh list with types is completed; for some items this should be the number of households in zone (eggs), this and next are not very helpful given there are multiple items in each group and this results in double counting (ie. 5 households that consume cassava does not make it 5 cassavas)
    # n_eat = length(annual_afe[annual_afe>0]), # number of items/times an item is consumed across all hh and group - TBD; pigs for example one household eats two items (meat & offal)
    
    # mean consumption - x
    mean_annual = mean(mean_afe), # includes non consumers - does not add much information, at most across producers but even that is not very informative
    mean_monthly = mean(mean_mo), # see above
    
    # consumers only
    mean_annual_eat = mean(mean_afe[annual_afe>0]), # average annual consumption among consumers
    sd_annual_eat = sd(mean_afe[annual_afe>0]),
    mean_monthly_eat = mean(mean_mo[annual_afe>0]), # only consumers
    sd_monthly_eat = sd(mean_mo[annual_afe>0])
    )%>% 
  ungroup()# use to compare to recall data

# meat needs to be addressed somewhat differently because of slaugter.. TBD


## ------------------------------------------------------------------------------------------------------------
sevendrecall %>% 
  group_by(zone, group)


## ------------------------------------------------------------------------------------------------------------
n_eat_hh <- sevendrecall %>% 
  mutate(
    item = ifelse(quant>0,1,0)
  ) %>% 
  group_by(y4_hhid, group, zone) %>% 
  summarise(
    items = sum(item)
  ) %>% 
  mutate(
    group_cons = ifelse(items>0, 1, 0)
  ) %>% 
  filter(!is.na(group)) %>%  # should not be necessary
  # statistics for table
  ungroup() %>% 
  group_by(group, zone) %>% # for table 1 only group, zone too granular
  summarise(
    mean_eat = mean(items),
    max = max(items),
    sum = sum(group_cons) # number of households consuming food group
  )

sevendrecall %>% # contains duplicated rows due to match to multiple
  mutate(
    quant_mo = quant*4.3,
    ppurch = purch*100/quant,
    pprod = produced*100/quant,
    pgifts = gifts*100/quant) %>% 
  group_by(group) %>% 
  summarise(
    # number and share of consuming households - REVISE USE ABOVE!
    # n_cons = length(quant[quant>0]), # number of times a household consumes an item from the group.... TBD
    # perc = n_cons*100/nrow(excl_3b[status == "included"]), # percentage of all households
    # mean monthly consumption
    mean_month = mean(quant_mo), # of all households (not just consumers)
    mean_cons = mean(quant_mo[quant>0]), # same but just consumers
    prods = mean(pprod[quant>0]), # mean perc from prodcution if consuming
    nproduce = length(quant[quant>0]), # number of households
    purchs = mean(ppurch[quant>0]), #mean perc from purch if consuming
    npurch = length(quant[quant>0]),
    pgift = mean(pgifts[quant>0]), # mean per from gifts if consuming
    ngifts = length(quant[quant>0]))


## ----eval=FALSE----------------------------------------------------------------------------------------------
# # 3) Generate group estimates for comparison
# grgrhh <- LSMS_ag_hh_match %>%
#   select(itemcode = hh_product, new_name_hh, group) %>%
#   unique() %>%
#   filter(!is.na(itemcode))
# 
# grhh <- prod.afe.range %>%
#   left_join(grgrhh, by = "itemcode") %>%
#   group_by(zone, new_name_hh) %>%
#   summarise(
#     mid = sum(annual_afehht),
#     max = sum(annual_afehhmx),
#     min = sum(annual_afemn)
#   ) %>%
#   ungroup()
# # this can now be extended by food groups that are aligned with the agricultural food groups and then these values can be compared
# 
# miss_var_summary(grhh)
# grgrhh %>% filter(is.na(new_name_hh))
# 
# # move to where this should be - comparison for items
# grgrag <- LSMS_ag_hh_match %>%
#   select(item, new_name_ag) %>%
#   unique() %>%
#   mutate(
#     new_name_ag = ifelse(is.na(new_name_ag), item, new_name_ag),
#     item = str_to_sentence(item)) %>%
#   filter(!is.na(new_name_ag)) # for now.
# 
# grag <- produce_long %>%
#   filter(product_type != "Slaughter product" & product_type != "Other crops") %>%
#   select(y4_hhid, item, produced, consumed) %>%
#   left_join(grgrag, by = "item") %>%
#   group_by(y4_hhid, new_name_ag) %>%
#   summarise(
#     production = sm(produced),
#     consumption = sm(consumed)
#   )
# 
# # reconstruct full names & join with groupsgroups
# shortnames <- read_excel("2_data/reference/shortnames.xlsx")
# 
# groupsgroupshh <- LSMS_ag_hh_match %>%
#   select(product_type, type, itemcode = hh_product) %>%
#   unique() %>% filter(!is.na(itemcode)) %>%
#   mutate(across(1:2, ~str_to_sentence(.x)))
# 
# # annual consumption for entire zone based on bootstrap and AFE
# amp_boot_gr <- amp_boot %>%
#   pivot_longer(
#     cols= 2:60,
#     names_to = "shortnames",
#     values_to = "cons_a" # annual consumption for the zone
#   ) %>%
#   left_join(shortnames, by = "shortnames") %>%
#   # manual adjustments
#   left_join(groupsgroupshh, by = "itemcode") %>%
#   group_by(zone, group) %>%
#   summarise(ap_cons = sum(cons_a)) %>%  # total consumption of food group in zone from production
#   pivot_wider(
#     names_from = zone,
#     values_from = ap_cons)
# 
# # extrapolate from ame to total household
# 
# ame_zone <- aFMe_summaries %>%
#   left_join(select(hhA, y4_hhid, zone), by = "y4_hhid") %>%  # add zones
#   group_by(zone) %>%
#   summarise(
#     ame_total = sum(hhafe)
#   ) %>%
#   filter(!is.na(zone)) # investigate
# 
# full_boot <- amp_boot %>%
#   pivot_longer(cols = 2:6, names_to = "zone", values_to = "ap_cons") %>%
#   left_join(ame_zone, by = "zone") %>%
#   mutate(
#     total_consumption = ame_total*ap_cons
#   )
# 
# compare_totals <- production %>%
#   right_join(select(full_boot, group, zone, total_cons_boot = total_consumption), by = c("group", "zone")) %>%
#   mutate(
#     diff = total_consumption - total_cons_boot
#   )


## ------------------------------------------------------------------------------------------------------------
prod_boot <- readRDS("2_data/final/prod_boot_fin.RDS") # average across samples, consumption for each household per month

# lists each household's consumption for every month
prod_boot_month <- do.call("rbind", lapply(names(prod_boot), function(x) cbind(zone = x, prod_boot[[x]])))

# total annual consumption for each household
prod.annual.per.afe2 <- prod_boot_month %>% 
  group_by(y4_hhid, zone) %>% 
  summarise(across(1:60, sum)) 

# add household afe

saveRDS(prod_boot_month, "2_data/results/prod_boot_month.RDS")
write_csv(prod.annual.per.afe2, "2_data/results/prod.annual.per.afe2.csv")


## ----prod boot 1---------------------------------------------------------------------------------------------
prod_boot <- readRDS("2_data/final/prod_boot.RDS")

# 1) Mean annual afe 
# contains annual consumption for 10,000 years, each year represents afe consumption for all households in the zone

# determine annual consumption in zone by using mean (& spread..) across years sampled for each zone
prod.annual.mean <- lapply(prod_boot, function(df){
  dfl <- df %>% 
    select(!c(month, .n)) %>% # meaningless
    summarise(across(1:60, mean)) # mean of all years sampled
  })

# "final" estimate of annual afe consumption for each zone
prod.annual.mean <- do.call("rbind", lapply(names(prod.annual.mean), function(x) cbind(zone = x, prod.annual.mean[[x]])))


# standard deviation separately
prod.annual.sd <- lapply(prod_boot, function(df){
  dfl <- df %>% 
    select(!c(month, .n)) %>% # meaningless
    summarise(across(1:60, stats::sd)) # sd of all years sampled
  })

# "final" estimate of annual afe consumption for each zone
prod.annual.sd <- do.call("rbind", lapply(names(prod.annual.sd), function(x) cbind(zone = x, prod.annual.sd[[x]])))

 
# standard error - TBD depends on whether this measure is used in an MFA
# library(plotrix)
# std.error()

prod.annual.mean
prod.annual.sd

# add number of AFEs



## ------------------------------------------------------------------------------------------------------------
n <- readRDS("2_data/final/n.RDS")
# each zone now contains number of household AFEs, estimate one AFE/average AFE consumption in zone
prod.annual.per.afe <- prod.annual.mean %>% 
  left_join(n) %>% 
  mutate(across(alocohol:yams, ~./n)) 

saveRDS(prod.annual.per.afe, "2_data/final/prod.annual.per.afe.RDS", compress = T)


## ----prod boot 2 - new afe estimates-------------------------------------------------------------------------
afe_mopres_hh <- read_csv("2_data/results/afe_mopres_hh.csv")
# 2) reshape and estimate hhafe
# afe summaries
afe_zone <- afe_mopres_hh %>% 
  left_join(hhA, by = "y4_hhid") %>% 
  rm_excl() %>% 
  group_by(zone) %>% 
  summarise(
    afe_7d_presanzone = sum(afe_7d_mo)/12, # "Recall members only when present", total number of months in the year
    afe_all_presanzone = sum(afe_all_mo)/12, # # "All members only when present"
    afe_7d_anzone = sum(afe_7d), # "Recall members all year long"
    afe_all_anzone = sum(afe_all), # "All members all year long"
    eaters = sum(eat7d),
    persons = sum(hh_person)
) 

afe_zone$meanafe <- rowMeans(afe_zone[,2:5]) # mean across afe estimates

# annual consumption for entire zone based on bootstrap and AFE
shortnames <- read_excel("2_data/reference/shortnames.xlsx")

prod.afe.range <- prod.annual.per.afe %>% 
  pivot_longer(
    cols= 2:61,
    names_to = "shortnames",
    values_to = "cons_a" # annual consumption for the zone if each household was one AFE
  ) %>% 
  left_join(shortnames, by = "shortnames") %>% 
  select(!shortnames) %>% 
  left_join(afe_zone, by = "zone") %>% 
  mutate(across(afe_7d_presanzone:meanafe, ~.*cons_a, .names = "cons_{.col}")) %>% 
  select(!c(afe_7d_presanzone:meanafe)) 

# standard deviation across estimates
prod.afe.range <- transform(prod.afe.range, row_stdev=apply(prod.afe.range, 1, sd, na.rm=TRUE))

# mean across annual consumption estimates based on range of afe estiamtes (inlcude meanafe?)
prod.afe.range$meanafe <- rowMeans(prod.afe.range[,5:8]) # mean annual total zone consumption across afe estimates
# prod.afe.range$annual_meanafe <- prod.afe.range$meanafe * prod.afe.range$cons_a
prod.afe.range


## ----prod boot 2, eval=FALSE---------------------------------------------------------------------------------
# # 2) reshape and estimate hhafe
# # afe summaries
# afe_zone <- aFMe_summaries %>%
#   left_join(hhA, by = "y4_hhid") %>%
#   rm_excl() %>%
#   group_by(zone) %>%
#   summarise(
#     afehht = sum(afehh), # no missing
#     afemx = sum(afehhmax),
#     afemn = sum(afehhmin)
#   )
# afe_zone$meanafe <- rowMeans(afe_zone[,2:4]) # mean across afe estimates
# 
# # annual consumption for entire zone based on bootstrap and AFE
# shortnames <- read_excel("2_data/reference/shortnames.xlsx")
# 
# prod.afe.range <- prod.annual.per.afe %>%
#   pivot_longer(
#     cols= 2:61,
#     names_to = "shortnames",
#     values_to = "cons_a" # annual consumption for the zone if each household was one AFE
#   ) %>%
#   left_join(shortnames, by = "shortnames") %>%
#   select(!shortnames) %>%
#   left_join(afe_zone, by = "zone") %>%
#   mutate(across(afehht:afemn, ~.*cons_a, .names = "annual_{.col}")) %>% # including meanafe messes up the sd
#   select(!c(afehht:meanafe))
# 
# # standard deviation across estimates
# prod.afe.range <- transform(prod.afe.range, row_stdev=apply(prod.afe.range, 1, sd, na.rm=TRUE))
# 
# # mean across annual consumption estimates based on range of afe estiamtes (inlcude meanafe?)
# prod.afe.range$meanafe <- rowMeans(prod.afe.range[,6:8]) # mean annual total zone consumption across afe estimates
# # prod.afe.range$annual_meanafe <- prod.afe.range$meanafe * prod.afe.range$cons_a
# prod.afe.range


## ----prod boot 3---------------------------------------------------------------------------------------------
# select variables for comparison with agricultural survey
boot4comp <- prod.afe.range %>%
  mutate(
    annual_meanafe = cons_a * meanafe,
    itemcode = str_to_sentence(itemcode)) %>% 
  select(zone, itemcode, meanafe, row_stdev) %>% # 
  left_join(hh_names)

saveRDS(boot4comp, "2_data/final/boot4comp.RDS", compress = T)


## ------------------------------------------------------------------------------------------------------------
hh_grps <- read_csv("2_data/final/hh_grps.csv")
prod_boot_total <- readRDS("2_data/final/prod_boot_total.RDS")

prod_boot_total <- do.call("rbind", lapply(names(prod_boot_total), function(x) cbind(zone = x, prod_boot_total[[x]])))

# total annual consumption per household
prd.bt.annual <- prod_boot_total[, lapply(.SD, sm), .SDcols = is.numeric, by=.(y4_hhid)]

# total annual by food group and household
prd.bt.annual.food.groups <- prd.bt.annual %>% 
  select(y4_hhid, alocohol:yams) %>% 
  melt(id.vars = "y4_hhid", variable.name = "shortnames") %>% 
  left_join(hh_grps, by = "shortnames") %>% 
  group_by(y4_hhid, group) %>% 
  summarise(
    quant = sum(value)
  )

saveRDS(prd.bt.annual.food.groups, "2_data/results/prd.bt.annual.food.groups.RDS", compress = T)
write_csv(prd.bt.annual.food.groups, "2_data/results/prd.bt.annual.food.groups.csv")

