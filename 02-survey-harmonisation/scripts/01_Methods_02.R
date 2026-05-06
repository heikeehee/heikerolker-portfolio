## ----setup, include=FALSE------------------------------------------------------------------------------------
library(data.table)
library(tidyverse)
library(Hmisc)
library(readxl)
library(collapse)
library(naniar)
library(gt)
library(readr)
library(magrittr)


## ----functions, include = FALSE------------------------------------------------------------------------------
sm <- function(x) sum(x, na.rm=TRUE)
mn <- function(x) mean(x, na.rm=T)
rd <- function(df) df %>% dplyr::mutate_if(is.numeric, round, 1)

clear.labels <- function(x) {
  if(is.list(x)) {
    for(i in seq_along(x)) {
      class(x[[i]]) <- setdiff(class(x[[i]]), 'labelled') 
      attr(x[[i]],"label") <- NULL
    } 
  } else {
    class(x) <- setdiff(class(x), "labelled")
    attr(x, "label") <- NULL
  }
  return(x)
}                  



## ----hfe overview 2, echo=FALSE------------------------------------------------------------------------------
# Household members
aFMe_summaries <- read_csv("2_data/final/aFMe_summaries.csv")

# # Final list of households
# excl_3b <- read_csv("2_data/final/excl_3b.csv") %>% 
#   filter(status == "included")

full_overview_hh4 <- fread("2_data/results/full_overview_hh4.csv")

# Food groups and name matching
LSMS_items_match <- readRDS("2_data/final/LSMS_items_match_fin.RDS") 


## ------------------------------------------------------------------------------------------------------------
# in 03_Descriptives
hh_grps <- LSMS_items_match %>% 
  select(itemcode, group) %>% 
  unique() %>% 
  filter(!is.na(itemcode)) %>% 
  filter(group != "slaughter") %>% 
  arrange(itemcode)

hh_grps <- hh_grps[-c(54),]

# add shortnames
shortnames <- read_excel("2_data/reference/shortnames.xlsx") %>% 
  mutate(itemcode = str_to_sentence(itemcode))

hh_grps <- hh_grps %>% 
  left_join(shortnames)

write_csv(hh_grps, "2_data/final/hh_grps.csv")

### Input data----
# recall_3b_appendix <- readRDS("2_data/final/recall_3b_appendix.RDS") %>% # undefined origin
#   mutate(itemcode = str_to_sentence(itemcode)) %>% 
#   # add food groups
#   left_join(select(hh_grps, group, itemcode), by = "itemcode")

recall_3b_appendix <- fread("2_data/results/recall_details.csv") %>% setDT() %>% 
  mutate(itemcode = str_to_sentence(itemcode)) %>% 
  left_join(select(hh_grps, group, itemcode), by = "itemcode")

write_csv(recall_3b_appendix, "2_data/results/recall_3b_appendix.csv")

# Overview and distribution
# Zone overview df - determine number of households per zone (not needed when using bootfun3)
n <- recall_3b_appendix %>% 
  select(y4_hhid, zone) %>% 
  group_by(zone) %>% 
  unique() %>% 
  dplyr::summarise(n = n())

# Overview of missing -> check after 3a revision!
miss_mo <- recall_3b_appendix %>% 
  select(zone, month, y4_hhid) %>% 
  unique() %>% 
  group_by(zone, month) %>% 
  summarise(
    n = n()
  ) %>% 
  pivot_wider(names_from = zone, values_from = n) %>% 
  mutate(across(2:6, ~replace_na(.,0))) %>% 
  arrange(month)

# AFE overview
hhA <- read_csv("2_data/files/hhA.csv") 
hhs <- recall_3b_appendix %>% 
  select(y4_hhid) %>% 
  unique() # duplication in approaches and why are they not aligned?

afe_dt <- aFMe_summaries %>% 
  right_join(hhs, by = "y4_hhid") %>%
  left_join(select(hhA, y4_hhid, zone), by = "y4_hhid") %>% # add zones
  select(y4_hhid, zone, contains("afe"))

afe_dt$mn.afe <- rowMeans(afe_dt[,3:5], na.rm = T)

afe_dt <- afe_dt %>% select(zone, y4_hhid, mn.afe)


## ------------------------------------------------------------------------------------------------------------
# mean weekly consumption per AFE by zone & month -> massive table (can be excluded but should be generated)
rec7d_ap <- recall_3b_appendix %>% 
  # select(y4_hhid, zone, itemcode, quant, purch, produced, gifts, month) %>%    # adjust as required once file final, per afe weekly consumption -> check if still the case
  select(y4_hhid, zone, itemcode, quant = quant_afe_mo, purch = purch_afe_mo, produced = produced_afe_mo, gifts = gifts_afe_mo, month) %>%
  # add food group file
  left_join(select(hh_grps, itemcode, group), by = "itemcode") %>% # group already present in recall_3b_appendix...
  ungroup() %>% 
  group_by(zone, month, y4_hhid, group) %>%
  summarise(
    count = length(quant[quant>0]), # item count if consumed
    sm.quant = sm(quant)) %>% # total per group consumed by each household
  ungroup() 

rec7d_ap_stats <- rec7d_ap %>% 
  dplyr::reframe(
    # n = n(), # redundant
    mn.items = mn(count),
    mn.cons = mn(sm.quant), # per household monthly consumption
    sd.cons = sd(sm.quant),
    md.cons = median(sm.quant),
    .by = c(zone, month, group)
      # IQR 
    ) 

# mean weekly consumption per AFE by zone & month -> massive table (can be excluded but should be generated)
rec7d_ap_items <- recall_3b_appendix %>% 
  select(y4_hhid, zone, itemcode, quant = quant_afe_mo, purch = purch_afe_mo, produced = produced_afe_mo, gifts = gifts_afe_mo, month) %>%
  left_join(select(hh_grps, itemcode, group), by = "itemcode") %>% # group already present in recall_3b_appendix...
  ungroup() %>% 
  group_by(zone, month, itemcode) %>%
  summarise(
    count = length(quant[quant>0]), # number of consumers
    mn.quant = mn(quant),
    sd.quant = sd(quant)) %>% # mean consumption of item in zone
  ungroup() 

miss_var_summary(recall_3b_appendix)
miss_var_summary(rec7d_ap_items)


## ------------------------------------------------------------------------------------------------------------
# Split data into sources & change shape----
boot_in <- copy(recall_3b_appendix)

zones <- boot_in %>% select(y4_hhid, zone, month) %>% unique() %>% setDT()

# length is number of households
boot_ap <- boot_in %>% 
  ungroup() %>% 
  arrange(shortnames) %>% 
  select(y4_hhid, zone, month, shortnames, var = quant_afe_mo) %>% # total afe monthly consumption as input
  pivot_wider(names_from = shortnames, values_from = var) %>% 
  setDT() %>% 
  mutate(across(5:63, ~replace_na(.x,0)))

boot_ap


## ----impute from months, include=FALSE-----------------------------------------------------------------------
set.seed(1234)

# define number of random samples for each month that is created
sl <- function(df) slice_sample(df, n = num, replace = TRUE)
num <- 10

# remove labels
df <- clear.labels(boot_ap)
boot_mo <- clear.labels(boot_ap) # copy to add sampled rows to

# central: 
  c1 <- df %>% 
    filter(zone == "Central" & (month == 2 | month ==4)) %>%
    sl() %>% 
    mutate(
      month = 3,
      y4_hhid = "99-99"
    )
  
  c2 <- df %>% 
    filter(zone == "Central" & (month == 7 | month == 10)) %>% # check if accurate...
    sl() %>% 
    mutate(
      month = 8,
      y4_hhid = "99-99"
    )
  
   c3 <- df %>% 
    filter(zone == "Central" & (month == 7 |month == 10)) %>%
    sl() %>% 
    mutate(
      month = 9,
      y4_hhid = "99-99"
    )
   
   # n=6
    c4 <- df %>% 
    filter(zone == "Central" & (month == 4 | month==5| month == 6)) %>%
    sl() %>% 
    mutate(
      month = 5,
      y4_hhid = "99-99"
    )
   
  # Lakes 
    # n = 8
  l <- df %>% 
    filter(zone == "Lakes" & (month == 8 | month == 9| month == 10)) %>%
    sl() %>% 
    mutate(
      month = 9,
      y4_hhid = "99-99"
    )
  
  # Nothern Highlands
  n1 <- df %>% 
    filter(zone == "Northern Highlands" & (month == 2 | month == 4)) %>%
    sl() %>% 
    mutate(
      month = 3,
      y4_hhid = "99-99"
    )
  
  n2 <- df %>% 
    filter(zone == "Northern Highlands" & (month == 8 | month == 10)) %>%
    sl() %>% 
    mutate(
      month = 9,
      y4_hhid = "99-99"
    )
  
  # n=6
  n3 <- df %>% 
    filter(zone == "Northern Highlands" & (month == 1 | month==12| month == 11)) %>%
    sl() %>% 
    mutate(
      month = 12,
      y4_hhid = "99-99"
    )
  
  # Southern Highlands
   sh1 <- df %>% 
    filter(zone == "Southern Highlands" & (month == 8 | month == 10)) %>%
    sl() %>% 
    mutate(
      month = 9,
      y4_hhid = "99-99"
    )
   
   # n = 8
  sh2 <- df %>% 
    filter(zone == "Southern Highlands" & (month == 1 | month == 2| month == 3)) %>%
    sl() %>% 
    mutate(
      month = 2,
      y4_hhid = "99-99"
    )
  
  # n = 8
  sh3 <- df %>% 
    filter(zone == "Southern Highlands" & (month == 4 | month == 2| month == 3)) %>%
    sl() %>% 
    mutate(
      month = 3,
      y4_hhid = "99-99"
    )
  
  # n=1
  sh4 <- df %>% 
    filter(zone == "Southern Highlands" & (month == 8 | month == 9| month == 10)) %>%
    sl() %>% 
    mutate(
      month = 9,
      y4_hhid = "99-99"
    )
   
df1 <- rbind(c1, c2, c3, c4, l, n1, n2, n3, sh1, sh2, sh3, sh4)

boot_spat_in <- rbind(df1, boot_mo)


## ----impute from zones, include=FALSE------------------------------------------------------------------------
set.seed(1234)

# define number of random samples for each month that is created
sl <- function(df) slice_sample(df, n = num, replace = TRUE)

# remove labels
df <- clear.labels(boot_ap)
boot_zo <- clear.labels(boot_ap)

# central: 
  c1 <- df %>% 
    filter(month == 3) %>%
    sl() %>% 
    mutate(
      zone = "Central",
      y4_hhid = "99-99"
    )
  
  c2 <- df %>% 
    filter(month == 8) %>%
    sl() %>% 
    mutate(
      zone = "Central",
      y4_hhid = "99-99"
    )
  
   c3 <- df %>% 
    filter(month == 9) %>%
    sl() %>% 
    mutate(
      zone = "Central",
      y4_hhid = "99-99"
    )
   
    c4 <- df %>% 
    filter(month==5) %>%
    sl() %>% 
    mutate(
      zone = "Central",
      y4_hhid = "99-99"
    )
   
  # Lakes 
  l <- df %>% 
    filter(month == 9) %>%
    sl() %>% 
    mutate(
      zone = "Lakes",
      y4_hhid = "99-99"
    )
  
  # Nothern Highlands
  n1 <- df %>% 
    filter(month == 3) %>%
    sl() %>% 
    mutate(
      zone = "Northern Highlands",
      y4_hhid = "99-99"
    )
  
  n2 <- df %>% 
    filter(month == 9) %>%
    sl() %>% 
    mutate(
      zone = "Northern Highlands",
      y4_hhid = "99-99"
    )
  
  n3 <- df %>% 
    filter(month==12) %>%
    sl() %>% 
    mutate(
      zone = "Northern Highlands",
      y4_hhid = "99-99"
    )
  
  # Southern Highlands
   sh1 <- df %>% 
    filter(month == 9) %>%
    sl() %>% 
    mutate(
      zone = "Southern Highlands",
      y4_hhid = "99-99"
    )
   
  sh2 <- df %>% 
    filter(month == 2) %>%
    sl() %>% 
    mutate(
      zone = "Southern Highlands",
      y4_hhid = "99-99"
    )
  
  sh2 <- df %>% 
    filter(month == 3) %>%
    sl() %>% 
    mutate(
      zone = "Southern Highlands",
      y4_hhid = "99-99"
    )
df1 <- rbind(c1, c2, c3, c4, l, n1, n2, n3, sh1, sh2, sh3)

boot_temp_in <- rbind(df1, boot_zo)


## ----complete missing 2--------------------------------------------------------------------------------------
zone_stats <- rec7d_ap_items %>% 
  group_by(zone, itemcode) %>% 
  summarise(
    count = mn(count), # average number of consumers across months in zone
    mn.quant = mn(mn.quant)) # average consumption in zone

cen <- zone_stats %>% 
  filter(zone == "Central") %>% setDT() 

central <- cen %>% 
  mutate(month = 3) %>% 
  bind_rows(cen) %>% 
  mutate(month = ifelse(is.na(month), 8, month)) %>% 
  bind_rows(cen) %>% 
  mutate(month = ifelse(is.na(month), 9, month)) %>% 
  relocate(month, .after = zone)

nh <- zone_stats %>% 
  filter(zone == "Northern Highlands") %>% setDT()

nohi <- nh %>% 
  mutate(month = 3) %>% 
  bind_rows(nh) %>% 
  mutate(month = ifelse(is.na(month), 9, month)) %>% 
  relocate(month, .after = zone)
  
crude_spatial_items <- rec7d_ap_items %>% 
  bind_rows(central, nohi) %>% 
  rename(
    cSn = count, cS = mn.quant, cSsd = sd.quant
  )

write_csv(crude_spatial_items, "2_data/appendix/crude_spatial_items.csv")
crude_spatial_items
miss_var_summary(crude_spatial_items)


## ----complete missing----------------------------------------------------------------------------------------
crude <- rec7d_ap %>% 
  group_by(month, zone, group) %>% 
  summarise(
    crude = mn(sm.quant)
  )

zone_stats <- rec7d_ap %>% 
  group_by(zone, group) %>% 
  summarise(
    crude = mn(sm.quant) # average group consumption across households
  )

cen <- zone_stats %>% 
  filter(zone == "Central") %>% setDT() 

central <- cen %>% 
  mutate(month = 3) %>% 
  bind_rows(cen) %>% 
  mutate(month = ifelse(is.na(month), 8, month)) %>% 
  bind_rows(cen) %>% 
  mutate(month = ifelse(is.na(month), 9, month)) %>% 
  relocate(month, .after = zone)

nh <- zone_stats %>% 
  filter(zone == "Northern Highlands") %>% setDT()

nohi <- nh %>% 
  mutate(month = 3) %>% 
  bind_rows(nh) %>% 
  mutate(month = ifelse(is.na(month), 9, month)) %>% 
  relocate(month, .after = zone)
  
crude_spatial_group <- crude %>% 
  bind_rows(central, nohi) %>% 
  rename(cS = crude)

write_csv(crude_spatial_group, "2_data/appendix/crude_spatial_group.csv")

crude_spatial_group
miss_var_summary(crude_spatial_group)


## ----impute by month-----------------------------------------------------------------------------------------
# starting position
month_stats <- rec7d_ap_items %>% 
  group_by(month, itemcode) %>% 
  summarise(
    count = mn(count), # average number of consumers across zones per month 
    mn.quant = mn(mn.quant)) # average consumption per month

mar <- month_stats %>% 
  filter(month == 3) 
  
aug <- month_stats %>% 
  filter(month == 8) %>% 
  mutate(zone = "Central") %>% 
  relocate(zone, .before = month)

sep <- month_stats %>% 
  filter(month == 9) %>% setDT() 

march <- mar %>% 
  mutate(zone = "Central") %>% 
  bind_rows(mar) %>% 
  mutate(zone = ifelse(is.na(zone), "Northern Highlands", zone)) %>% 
  relocate(zone, .before = month)

sept <- sep %>% 
  mutate(zone = "Central") %>% 
  bind_rows(sep) %>% 
  mutate(zone = ifelse(is.na(zone), "Northern Highlands", zone)) %>% 
  relocate(zone, .before = month)

crude_temporal_items <- rec7d_ap_items %>% 
  bind_rows(march, aug, sept) %>% 
  rename(
    cTn = count, cT = mn.quant, cTsd = sd.quant)

write_csv(crude_temporal_items, "2_data/appendix/crude_temporal_items.csv")

miss_var_summary(crude_temporal_items)
crude_temporal_items


## ------------------------------------------------------------------------------------------------------------
month_stats <- rec7d_ap %>% 
  group_by(month, group) %>% 
  summarise(
    crude = mn(sm.quant) # average group consumption across households
  )

mar <- month_stats %>% 
  filter(month == 3) 
  
aug <- month_stats %>% 
  filter(month == 8) %>% 
  mutate(zone = "Central") %>% 
  relocate(zone, .before = month)

sep <- month_stats %>% 
  filter(month == 9) %>% setDT() 

march <- mar %>% 
  mutate(zone = "Central") %>% 
  bind_rows(mar) %>% 
  mutate(zone = ifelse(is.na(zone), "Northern Highlands", zone)) %>% 
  relocate(zone, .before = month)

sept <- sep %>% 
  mutate(zone = "Central") %>% 
  bind_rows(sep) %>% 
  mutate(zone = ifelse(is.na(zone), "Northern Highlands", zone)) %>% 
  relocate(zone, .before = month)

crude_temporal_group <- crude %>% 
  bind_rows(march, aug, sept) %>% 
  rename(cT = crude)

write_csv(crude_temporal_group, "2_data/appendix/crude_temporal_group.csv")

miss_var_summary(crude_temporal_group)


## ------------------------------------------------------------------------------------------------------------
set.seed(2535)

# functions
reps <- 1000 # define reps; ultimately 10,000 or so
samp <- function(x) sample(x, size = N, replace =TRUE) # sampling function

# all item names
vars <- boot_spat_in %>% select(4:63) %>% names() 

# nested list with months
prep <- function(df, name = "name"){
  df_boot <- df[zone == name] # change here
  df_boot <- df_boot %>% 
    select(!c(zone, y4_hhid)) %>%       # vars not needed
    group_by(month)                     # group by month
  
  return(group_split(df_boot))          # split into nested list
}

afe_est <- function(name = "name"){
  afe_dt %>% 
    filter(zone == name) %>% 
    select(y4_hhid, mn.afe)
}

bootfun3 <- function(list){
  df_l2 <- lapply(list, function(df){
    df <- apply(df, 2, samp)  # dfs are months of the year, take random sample from each column representing a food item (2:cols, 1:rows), N=number of 'real' households
  })
  
  df_l3 <- lapply(df_l2, function(df){
    df <- cbind(df, AFE)
  }) 
  
  dfl4 <- rbindlist(df_l3) 

  # dfl5 <- dfl4[, (vars) := .SD * mn.afe, .SDcols = vars]
}

# boot clean
bootclean <- function(df){
  setDT(df)
  dfl6 <- df[, lapply(.SD, mn), .SDcols=vars, by=.(month, y4_hhid)] # calculate average per month for each household
  }


## ----eval=T--------------------------------------------------------------------------------------------------
boot_df <- copy(boot_spat_in)

start <- Sys.time()
# Central
df <- prep(boot_df, "Central")
AFE <- afe_est("Central")
N <- nrow(AFE)
boot_central <- plyr::rdply(reps, bootfun3(df))
bs.central <- bootclean(boot_central)

# Coastal
df <- prep(boot_df, "Coastal")
AFE <- afe_est("Coastal")
N <- nrow(AFE)
boot_coastal <- plyr::rdply(reps, bootfun3(df))
bs.coastal <- bootclean(boot_coastal)

# Lakes
df <- prep(boot_df, "Lakes")
AFE <- afe_est("Lakes")
N <- nrow(AFE)
boot_lakes <- plyr::rdply(reps, bootfun3(df))
bs.lakes <- bootclean(boot_lakes)

# 'Northern Highlands'
df <- prep(boot_df, 'Northern Highlands')
AFE <- afe_est("Northern Highlands")
N <- nrow(AFE)
boot_nohi <- plyr::rdply(reps, bootfun3(df))
bs.nohi <- bootclean(boot_nohi)

# 'Southern Highlands'
df <- prep(boot_df, 'Southern Highlands')
AFE <- afe_est("Southern Highlands")
N <- nrow(AFE)
boot_sohi <- plyr::rdply(reps, bootfun3(df))
bs.sohi <- bootclean(boot_sohi)

# save results in list 
boot_mo_hh <- list(bs.central, bs.coastal, bs.lakes, bs.nohi, bs.sohi)
names(boot_mo_hh) <- c("Central", "Coastal", "Lakes", "Northern Highlands", "Southern Highlands")

finish <- Sys.time()
dur2 <- difftime(start,finish)

saveRDS(boot_mo_hh, "2_data/appendix/boot_spatial_items.RDS", compress = T)


## ----eval=T--------------------------------------------------------------------------------------------------
boot_df <- copy(boot_temp_in)

start <- Sys.time()
# Central
df <- prep(boot_df, "Central")
AFE <- afe_est("Central")
N <- nrow(AFE)
boot_central <- plyr::rdply(reps, bootfun3(df))
bs.central <- bootclean(boot_central)

# Coastal
df <- prep(boot_df, "Coastal")
AFE <- afe_est("Coastal")
N <- nrow(AFE)
boot_coastal <- plyr::rdply(reps, bootfun3(df))
bs.coastal <- bootclean(boot_coastal)

# Lakes
df <- prep(boot_df, "Lakes")
AFE <- afe_est("Lakes")
N <- nrow(AFE)
boot_lakes <- plyr::rdply(reps, bootfun3(df))
bs.lakes <- bootclean(boot_lakes)

# 'Northern Highlands'
df <- prep(boot_df, 'Northern Highlands')
AFE <- afe_est("Northern Highlands")
N <- nrow(AFE)
boot_nohi <- plyr::rdply(reps, bootfun3(df))
bs.nohi <- bootclean(boot_nohi)

# 'Southern Highlands'
df <- prep(boot_df, 'Southern Highlands')
AFE <- afe_est("Southern Highlands")
N <- nrow(AFE)
boot_sohi <- plyr::rdply(reps, bootfun3(df))
bs.sohi <- bootclean(boot_sohi)

# save results in list 
boot_mo_hh <- list(bs.central, bs.coastal, bs.lakes, bs.nohi, bs.sohi)
names(boot_mo_hh) <- c("Central", "Coastal", "Lakes", "Northern Highlands", "Southern Highlands")

finish <- Sys.time()
dur2 <- difftime(start,finish)

saveRDS(boot_mo_hh, "2_data/appendix/boot_temporal_items.RDS", compress = T)


## ----missing, echo=FALSE-------------------------------------------------------------------------------------
miss_mo %>% 
  data.table::transpose(keep.names = "Zone", make.names = "month") %>% 
  gt() %>% 
  tab_header("Overview of number of household recalls by month and zone.")
# highlight 0 and < 10


## ----zones, echo=FALSE---------------------------------------------------------------------------------------
n %>% 
  gt() %>% 
  tab_header("Number of households in each zone")


## ------------------------------------------------------------------------------------------------------------
boot_spatial_items <- readRDS("2_data/appendix/boot_spatial_items.RDS")
# Boot spatial
# per AFE consumption for each household, item, month
boot_spatial <- do.call("rbind", lapply(names(boot_spatial_items), function(x) cbind(zone = x, boot_spatial_items[[x]])))

# wide to long with food groups
boot_spatial_long <- boot_spatial %>% 
  setDT() %>% 
  melt(id.vars = c("month","zone", "y4_hhid"), variable.name = "shortnames") %>% 
  left_join(hh_grps, by = "shortnames") 

saveRDS(boot_spatial_long, "2_data/appendix/boot_spatial_long.RDS")


## ------------------------------------------------------------------------------------------------------------
# collapse to month, zone, item
boot_spatial_items <- boot_spatial_long %>% 
  group_by(zone, month, group, itemcode) %>% 
  summarise(
    bSn = length(value[value>0]),
    bS = mn(value),
    bSsd = sd(value)
  )
write_csv(boot_spatial_items, "2_data/appendix/boot_spatial_items.csv")


## ------------------------------------------------------------------------------------------------------------
# collapse to month, zone, food group based on hh
boot_spatial_hh <- boot_spatial_long %>% 
  group_by(zone, month, group, y4_hhid) %>% 
  summarise(
    bSn = length(value[value>0]),
    bS = sm(value)
  ) %>% 
  ungroup() %>% 
    group_by(zone, month, group) %>% 
  summarise(
    bS = mn(bS)
  ) %>% 
  ungroup()

miss_var_summary(boot_spatial_hh)


## ------------------------------------------------------------------------------------------------------------
boot_temporal_items <- readRDS("2_data/appendix/boot_temporal_items.RDS")
# Boot spatial
# per AFE consumption for each household, item, month
boot_temporal <- do.call("rbind", lapply(names(boot_temporal_items), function(x) cbind(zone = x, boot_temporal_items[[x]])))

# wide to long with food groups
boot_temporal_long <- boot_temporal %>% 
  setDT() %>% 
  melt(id.vars = c("month","zone", "y4_hhid"), variable.name = "shortnames") %>% 
  left_join(hh_grps, by = "shortnames") 

saveRDS(boot_spatial_long, "2_data/appendix/boot_temporal_long.RDS")

# collapse to month, zone, food group based on hh
boot_spatial_hh <- boot_spatial_long %>% 
  group_by(zone, month, group, y4_hhid) %>% 
  summarise(
    bSn = length(value[value>0]),
    bS = sm(value)
  ) %>% 
  ungroup() %>% 
    group_by(zone, month, group) %>% 
  summarise(
    bS = mn(bS)
  ) %>% 
  ungroup()

miss_var_summary(boot_spatial_hh)


## ------------------------------------------------------------------------------------------------------------
# collapse to month, zone, item
boot_temporal_items <- boot_temporal_long %>% 
  group_by(zone, month, group, itemcode) %>% 
  summarise(
    bTn = length(value[value>0]),
    bT = mn(value),
    bTsd = sd(value)
  )
write_csv(boot_temporal_items, "2_data/appendix/boot_temporal_items.csv")

# collapse to month, zone, food group based on hh
boot_temporal_hh <- boot_temporal_long %>% 
  group_by(zone, month, group, y4_hhid) %>% 
  summarise(
    bTn = length(value[value>0]),
    bT = sm(value)
  ) %>% 
  ungroup() %>% 
    group_by(zone, month, group) %>% 
  summarise(
    bT = mn(bT)
  ) %>% 
  ungroup()

miss_var_summary(boot_temporal_hh)


## ------------------------------------------------------------------------------------------------------------
crude_spatial_items


## ------------------------------------------------------------------------------------------------------------
crude_temporal_items


## ------------------------------------------------------------------------------------------------------------
# join measures at the itemlevel
crude_items <- rec7d_ap_items %>% 
  select(zone, month, itemcode, crude = mn.quant) 

afe_comp_items <- crude_items %>% 
  full_join(crude_spatial_items) %>% 
  full_join(crude_temporal_items) %>% 
  full_join(boot_spatial_items) %>% 
  full_join(boot_temporal_items) %>% 
  mutate(crude = ifelse(is.na(crude), 0, crude)) # missing temporal-spatial context

miss_var_summary(afe_comp_items)

## ------------------------------------------------------------------------------------------------------------
afe_differences <- afe_comp_items %>% 
  select(zone, month, group, itemcode, crude, cS, cT, bS, bT)

# mean
afe_differences$mean <- rowMeans(afe_differences[,6:9], na.rm = T) # excludes crude - is that right?
# standard deviation needed?

# basis for all further calculation of differences
write_csv(afe_differences, "2_data/appendix/afe_differences.csv")

afe_differencesflourish <- afe_differences %>% 
  setDT() %>% # possibly diffs?
  select(!mean) %>% 
  melt(id.vars = c("zone", "month", "group", "itemcode"), variable.name = "method")  

write_csv(afe_differencesflourish, "2_data/results/afe_differencesflourish.csv")


## ------------------------------------------------------------------------------------------------------------
calc.diffs <- function(df, fun){ # add element for function
  df %>% 
    mutate(
      mean = (cS+cT+bS+bT)/4,
      diffccS = crude - cS, # calculate difference between proposed method and given data
      diffccT = crude - cT,
      diffcbS = crude - bS,
      diffcbT = crude - bT)
} 

calc.diff.stats <- function(df){
  df %>% 
    summarise(
      across(c(diffccS:diffcbT), ~ sd(.x, na.rm=T), .names = "sd.{.col}"), # sd first as following alters diff vars
      across(c(diffccS:diffcbT), ~ mn(.x)),
      n = n()
      ) %>% 
    mutate(
      se.ccS = sd.diffccS/sqrt(n),
      se.ccT = sd.diffccT/sqrt(n),
      se.cbS = sd.diffcbS/sqrt(n),
      se.cbT = sd.diffcbT/sqrt(n),
    # confidence interval - repeat for all
      lower.ci.ccS = diffccS - qt(1 - (0.05/2), n -1) * se.ccS,
      upper.ci.ccS = diffccS + qt(1 - (0.05/2), n -1) * se.ccS,
      lower.ci.ccT = diffccT - qt(1 - (0.05/2), n -1) * se.ccT,
      upper.ci.ccT = diffccT + qt(1 - (0.05/2), n -1) * se.ccT,
      lower.ci.cbS = diffcbS - qt(1 - (0.05/2), n -1) * se.cbS,
      upper.ci.cbS = diffcbS + qt(1 - (0.05/2), n -1) * se.cbS,
      lower.ci.cbT = diffcbT - qt(1 - (0.05/2), n -1) * se.cbT,
      upper.ci.cbT = diffcbT + qt(1 - (0.05/2), n -1) * se.cbT
  )
}

name_months <- function(df){
  df %>% 
    mutate(
      month = fcase(
      month == 1, "January",
      month == 2, "February",
      month == 3, "March",
      month == 4, "April",
      month == 5, "May",
      month == 6, "June",
      month == 7, "July",
      month == 8, "August",
      month == 9, "September",
      month == 10, "October",
      month == 11, "November",
      month == 12, "December"),
      month = factor(month, 
                     levels = c("January", "February", "March", "April", "May", "June",
                                "July", "August", "September", "October", "November", "December")))
}


## ------------------------------------------------------------------------------------------------------------
# difference as is at item level
afe_differences %>% 
  calc.diffs()


## ------------------------------------------------------------------------------------------------------------
# difference at group level, when means are added
afe_differences %>% 
  group_by(zone, month, group) %>% 
  summarise(across(c(crude:bT), ~ sm(.x))) %>% # total consumption 
  calc.diffs()

# differences at group level when grouped at earlier stage
differences_hh_grouped <- crude %>% 
  full_join(boot_spatial_hh) %>% 
  full_join(boot_temporal_hh) %>% 
  full_join(crude_temporal_group) %>% 
  full_join(crude_spatial_group) %>% 
  mutate(
    crude = ifelse(is.na(crude), 0, crude)
  )

differences_hh_grouped %>% 
  calc.diffs()


## ------------------------------------------------------------------------------------------------------------
# differences in average total annual per AFE consumption in zone
tab1 <- differences_hh_grouped %>% 
  group_by(zone) %>% 
  summarise(across(c(crude:cS), ~ sm(.x)))  %>% # total consumption by adding up mean group values
  calc.diffs()

tab1alt <- afe_differences %>% 
  group_by(zone, month, group) %>% 
  summarise(across(c(crude:bT), ~ sm(.x))) %>% # total consumption 
  ungroup() %>% 
  group_by(zone) %>% 
  summarise(across(c(crude:bT), ~ sm(.x))) %>% # total consumption 
  calc.diffs()

write_csv(tab1, "2_data/results/1_overall_diffs.csv")


## ------------------------------------------------------------------------------------------------------------

# adding the means at group level
fig2 <- differences_hh_grouped %>% 
  group_by(group) %>% 
  summarise(across(c(crude:cS), ~ mn(.x))) %>% # total consumption 
  calc.diffs()

# adding the means at item level
fig2alt <- afe_differences %>% 
  group_by(group, month, zone) %>% 
  summarise(across(c(crude:bT), ~ sm(.x))) %>% # calculate the sum for each food group from item list per month-zone (i.e. add all item means to give an average for the group)
  ungroup() %>% 
  group_by(group) %>% 
  summarise(across(c(crude:bT), ~ mn(.x))) %>% # calculate tg
  calc.diffs()

write_csv(fig2, "2_data/results/1_group_diffs.csv")


## ------------------------------------------------------------------------------------------------------------
# differences in average total annual per AFE consumption in zone
fig3 <- differences_hh_grouped %>% 
  group_by(zone, month) %>% 
  summarise(across(c(crude:cS), ~ sm(.x)))  %>% # total consumption across all groups in month for each zone
  ungroup() %>% 
  group_by(month) %>% 
  summarise(across(c(crude:cS), ~ mn(.x))) %>%  # average monthly consumption across zones
  calc.diffs() %>% 
  name_months()

# not the same as above yet.
fig3alt <- afe_differences %>% 
  group_by(zone, month, group) %>% 
  summarise(across(c(crude:bT), ~ sm(.x))) %>% # total consumption 
  ungroup() %>% 
  group_by(month) %>% 
  summarise(across(c(crude:bT), ~ mn(.x))) %>% # total consumption 
  calc.diffs() %>% 
  name_months()

write_csv(fig3, "2_data/results/1_monthly_diffs.csv")


## ------------------------------------------------------------------------------------------------------------
fig4 <- differences_hh_grouped %>% 
  mutate(
    imputed = ifelse(
      (zone == "Central" & (month == 3 | month == 8 | month == 9)) | (zone == "Northern Highlands" & (month == 3 | month == 9)), "yes", "no")) %>% 
  calc.diffs()

write_csv(fig4, "2_data/results/1_imputed_diffs.csv")


## ------------------------------------------------------------------------------------------------------------
diff_means <- afe_differences %>% 
  calc.diffs() 

colMeans(diff_means[,11:14], na.rm = T)


## ------------------------------------------------------------------------------------------------------------
# could be the mean of total consumption across households - correct data input?
groups_annual <- afe_differences %>% 
  group_by(zone, group) %>% 
  summarise(across(c(crude:mean), ~ sm(.x))) %>%   # total consumption for group by zone
  ungroup() %>% 
  group_by(group) %>% # average of total across zones
  summarise(across(c(crude:mean), ~ mn(.x)))

# match_items1 <- groups_annual %>% 
#   select(group) %>% 
#   unique()
# write_csv(match_items1, "2_data/reference/match_items.csv")

match_FAO_items <- read_excel("2_data/reference/match_FAO_items.xlsx")

FAOSTAT <- read_csv("2_data/reference/FAOSTAT_data_en_6-18-2024.csv") %>% 
  # rename items to align with above
  full_join(match_FAO_items) %>% 
  # calculate average across the two years
  group_by(Item, group) %>% 
  summarise(
    FAO = mn(Value)
  ) %>% 
  group_by(group) %>% 
  summarise(
    crude = sm(FAO) # to make function work
  ) %>% 
  filter(!is.na(group))
  
# combine data
FAO_comparison <- groups_annual %>% 
  select(!crude) %>% 
  full_join(FAOSTAT) %>% 
  mutate(
    group = ifelse(grepl("veg",group), "vegetable and vegetable products", group),
    group = ifelse(grepl("spices",group), "condiments and spices", group)) %>% 
  group_by(group) %>% 
  summarise(across(c(cS:crude), ~ sm(.x))) %>% 
  # calculate difference to FAO data
  calc.diffs()

saveRDS(FAO_comparison, "2_data/results/FAO_comparison.RDS")
write_csv(FAO_comparison, "2_data/results/FAO_comparison.csv")

## ----redo FAO with per capita--------------------------------------------------------------------------------
afe_mopres_hh <- read_csv("2_data/final/afe_mopres_hh.csv")
new_faocomp <- recall_3b_appendix %>% 
  select(!contains("afe")) %>% 
  mutate(
    quant_mo = quant*4.3) %>% # extrapolate to monthly for direct comparison to FAO
  group_by(y4_hhid, group, month) %>% 
  summarise(
    quant_mo = sm(quant_mo)) %>%  # monthly household availability of food group
  left_join(select(afe_mopres_hh, y4_hhid, hh_person)) %>% 
  # mutate(
  #   mo_pcap = quant_mo/hh_person) %>% # per capita household availability
  ungroup() %>% 
  group_by(group, month) %>% 
  # summarise(
  #   mean_total = mn(quant_mo),
  #   mean_percapita = mn(mo_pcap)
  # ) %>% 
  summarise(
    total_mo = sm(quant_mo),
    # mean_percapita = sm(mo_pcap),
    ppl = sm(hh_person),
    percap_mo = total_mo/ppl
  ) %>% 
  group_by(group) %>% 
  summarise(
    percap_an = mn(percap_mo), # average availability of food group per month across the year
    total_an = sm(total_mo), # total consumption in sample
    percap = total_an/sum(afe_mopres_hh$hh_person) # annual availability divided by all people
  )


FAOSTAT <- read_csv("2_data/reference/FAOSTAT_data_en_6-18-2024.csv") %>% 
  # rename items to align with above
  full_join(match_FAO_items) %>% 
  # calculate average across the two years
  group_by(Item, group) %>% 
  summarise(
    FAO = mn(Value)
  ) %>% 
  group_by(group) %>% 
  summarise(
    FAO = sm(FAO)/12 # to make function work
  ) %>% 
  filter(!is.na(group))
  
# combine data
FAO_comparison_new <- new_faocomp %>% 
  full_join(FAOSTAT) %>% 
  mutate(
    group = ifelse(grepl("veg",group), "vegetable and vegetable products", group),
    group = ifelse(grepl("spices",group), "condiments and spices", group)) %>% 
  group_by(group) %>% 
  summarise(across(is.numeric, ~ sm(.x))) 
  # group_by(group) %>% 
  # summarise(across(c(cS:crude), ~ sm(.x))) %>% 
  # calculate difference to FAO data
  # calc.diffs()

write_csv(FAO_comparison_new, "2_data/results/FAO_comparison.csv")

