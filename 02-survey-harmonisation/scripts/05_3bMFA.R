## ------------------------------------------------------------------------------------------------------------
library(RColorBrewer)
library(plotly)


## ------------------------------------------------------------------------------------------------------------
excl_3b <- read_csv("2_data/final/excl_3b.csv")

incl_3b <- excl_3b %>% 
  filter(status == "included") %>% 
  select(y4_hhid)


## ------------------------------------------------------------------------------------------------------------
produce_long <- readRDS(here("..", "03a_simpleMFA", "2_data/final", "produce_long.RDS"))

# read in data from 3a -  remove all weighting
# add zone information -> this should be only included from 3b
hh3bfin <- read_csv(here("..", "03b_MFA_connect", "2_data/final", "excl_3b.csv")) %>%
  filter(status == "included") %>% 
  select(y4_hhid, zone) %>% 
  mutate(y4_hhid = as.character(y4_hhid))

# Remove excluded households and fill 0 values for non producers (relevant for animal products only)
mfa_crops <- readRDS(here("..", "03a_simpleMFA", "2_data/final", "mfa_crops.RDS")) %>% 
  inner_join(incl_3b) %>% 
  mutate(item = str_to_sentence(item)) %>% 
  select(!type) %>% 
  right_join(ag_names, by = "item") %>% 
  rename(type = group) %>% 
  inner_join(hh3bfin) %>% 
  filter(!is.na(y4_hhid))

mfa_animals <- readRDS(here("..", "03a_simpleMFA", "2_data/final", "mfa_animals.RDS")) %>% 
  ungroup() %>% 
  inner_join(incl_3b) %>% 
  inner_join(hh3bfin)

items <- readRDS(here("..", "03a_simpleMFA", "2_data/final", "mfa_animals.RDS")) %>% 
  select(type, lvstckid) %>% 
  unique()

mfa_eggs <- readRDS(here("..", "03a_simpleMFA", "2_data/final", "mfa_eggs.RDS")) %>% 
  inner_join(incl_3b) %>% 
  inner_join(hh3bfin)

mfa_milk <- readRDS(here("..", "03a_simpleMFA", "2_data/final", "mfa_milk.RDS")) %>% 
  inner_join(incl_3b) %>% 
  inner_join(hh3bfin)

mfa_hides <- readRDS(here("..", "03a_simpleMFA", "2_data/final", "mfa_hides.RDS")) %>% 
  inner_join(incl_3b) %>% 
  inner_join(hh3bfin)


## ------------------------------------------------------------------------------------------------------------
sankey <- function(data){
  nodes <- data.frame(name=c(as.character(data$source), as.character(data$target)) %>% unique())
  
  data$IDsource <- match(data$source, nodes$name)-1 
  data$IDtarget <- match(data$target, nodes$name)-1
  
  data <- data %>% 
    mutate_if(is.character, str_to_sentence)
  
  nb.cols <- nrow(nodes)
  mycolors <- colorRampPalette(brewer.pal(11, "PiYG"))(nb.cols)
  
  
  fig <- plot_ly(
    type = "sankey",
    orientation = "h",
    
    node = list(
      label = nodes$name,
      color = mycolors,
      pad = 15,
      thickness = 20,
      line = list(
        color = "black",
        width = 0.5
      )
    ),
    
    link = list(
      source = data$IDsource,
      target = data$IDtarget,
      value =  data$value,
      color = "light grey"
      
    )
  )
  # fig <- fig %>% layout(
  #   title = "Material Flow LSMS-ISA TZA wave 4",
  #   font = list(
  #     size = 10
  #   )
  #)
  fig
}


## ------------------------------------------------------------------------------------------------------------
# applicable to all
calc <- function(df) df[, lapply(.SD, sm), .SDcols=is.numeric, by=.(type)] # change function and grouping as required; for 3c this could stay item; use groupsgroups for other aggregation levels
# col sum
cl <- function(df) df[, lapply(.SD, sm), .SDcols=is.numeric] # change function as required


## ------------------------------------------------------------------------------------------------------------
reconcile <- readRDS("2_data/final/reconcile.RDS") # reconcile at the food group level

mfacrops <- function(df){
df <- cmfa[!is.na(type)] # households that were "added" for completion, they will probably need a type and item across all df with 0 values to represent the full sample in all dfs - TBD
# df <- df[type != "cashcrops"] # not needed for this one

  c1 <- calc(df)
  c2 <- cl(df)
  
  # replace consumption value with reconciled quantities
  # reconstruct groups - possibly done at item level like with matching - TBD
  c1 <- c1 %>% 
    setDT() %>% 
    filter(produced>0) %>% 
    left_join(select(reconcile, type = group, produced4cons, mean_value), by = "type") %>% 
    mutate(
      disconnect = (produced4cons-mean_value),
      missing_rec = ifelse(disconnect<0, disconnect*-1, 0),
      unallocated_rec = ifelse(disconnect>0, disconnect, 0)# 
    )

  # first flow: harvest
  first <- c1[,. (source = type, value = produced)]
  first[, target := "Produced"]
  
  # second flow: harvest onward
  second <- c1[,.(source = type, 
                  consumed, 
                  sold, 
                  payment,
                  gifts,
                  losses, 
                  stored, 
                  feed, 
                  processing,
                  unallocated,
                  missing)] # this is uncertain partially from the ag survey only
  
  second <- melt(second, id.vars = "source",
                 measure.vars = c("consumed", "sold", "payment", "gifts", "losses", "stored", "feed", "processing", "unallocated", "missing"))
  
  second <- upData(second,
                   rename = .q(variable = target))
  
  # third flow: processing
  third <- data.table(
    source = "processing",
    target = c("sold", "consumed", "waste"),
    value = c(pluck(c2$prodsold), pluck(c2$prodconsumed), pluck(c2$waste))
  )
  
  fourth <- data.table(
    source = "stored",
    target = "seed",
    value  = pluck(c2$seed)
  )

  # recall
  rec <- data.table(
    source = c("consumed", "consumed", "consumed"),
    target = c("recall", "unallocated", "missing"),
    value = c(sm(c1$mean_value)*1000, sm(c1$unallocated_rec)*1000, sm(c1$missing_rec)*1000) # instead of using the mean value I could produce another set without reconciled data and consumedFprod
  )
  
  data <- rbind(second, third, fourth, rec)
  data <- data %>% select(target, source, value)}

# reconcile <- reconcile_zone %>% filter(zone == "Central")
cmfa <- copy(mfa_crops) 
data <- mfacrops(cmfa)
sankey(data)


c1 <- calc(mfa_crops)
  
  # replace consumption value with reconciled quantities
  # reconstruct groups - possibly done at item level like with matching - TBD
  cropc1 <- c1 %>% 
    setDT() %>% 
    filter(produced>0) %>% 
    left_join(select(reconcile, type = group, produced4cons, mean_value), by = "type") %>% 
    mutate(
      disconnect = (produced4cons-mean_value) # 
    )
  
saveRDS(cropc1, "2_data/results/cropc1.RDS")  


## ------------------------------------------------------------------------------------------------------------
mfamilk <- function(df){
  
  recegg <- comp.quant2 %>% 
    filter(group == "milk and dairy products") %>% 
    mutate(
    unallocated = ifelse(difference < 0, difference *-1, 0), # more produced than consumed, i.e. waste
    missing = ifelse(difference > 0, difference, 0)
  ) %>% 
  select(group, zone, produced4cons, consumedFprod, unallocated, missing) %>%
  group_by(group) %>% # ignore zone for now
  summarise(
    produced4cons = sm(produced4cons),
    consumedFprod = sm(consumedFprod),
    unallocated = sm(unallocated),
    missing = sm(missing)
  ) %>%
  mutate(mean_value = (produced4cons+consumedFprod)/2,
         unallocated = produced4cons-mean_value) %>% 
  setDT()

# calculate
  mi1 <- calc(df)
  mi2 <- cl(df)
  
  # feed
  # feed <- melt(mi1, id.vars = "type",
  #              measure.vars = c("feed", "grazed"))
  # feed <- upData(feed, rename = .q(variable = source, type = target))
  
  # feed to production
  firsti <- data.table(
    source = c("large ruminants", "small ruminants"),
    target = "milked",
    value = c(pluck(mi1[1,4]), pluck(mi1[2,4])) # shaky as code..
  )

  
  # first flow production onward
  first <- mi1[,.(source = type, 
                  consumed, 
                  sold, 
                  processed, 
                  missing,
                  unallocated)]
  
  first <- melt(first, id.vars = "source",
                measure.vars = c("consumed", "sold", "processed", "missing", "unallocated"))
  first <- upData(first,
                  rename = .q(variable = target),
                  source = "milked")
  
  # second flow processing to sold & consumed
  second <- data.table(
    source = 
      "processed",
    target = 
      c("sold", "uncertain"),
    value = c(
      pluck(mi2$psold), pluck(mi2$processed)-pluck(mi2$psold))
  )
  
  rec <- data.table(
    source = c("consumed", "consumed"),
    target = c("recall", "unallocated"),
    value = c(pluck(recegg$mean_value)*1000, pluck(recegg$unallocated)*1000)
  )
  
  data3 <- rbind(firsti, first, second, rec)}

df <- copy(mfa_milk)
recegg <- reconcile %>% 
    filter(group == "milk and dairy products")
data3 <- mfamilk(df)
sankey(data3)


## ------------------------------------------------------------------------------------------------------------
df <- copy(mfa_animals)
df2 <- copy(mfa_hides)
# collapse and calculate
mfameat <- function(df, df2){
  
  meat_rec <- comp.quant2 %>% 
  filter(new_name_ag != "Eggs" & grepl("meat", group)) %>% 
  mutate(
    unallocated = ifelse(difference < 0, difference *-1, 0), # more produced than consumed, i.e. waste
    missing = ifelse(difference > 0, difference, 0)
  ) %>% 
  select(group, zone, produced4cons, consumedFprod, unallocated, missing) %>%
  group_by(group) %>% # ignore zone for now
  summarise(
    produced4cons = sm(produced4cons),
    consumedFprod = sm(consumedFprod),
    unallocated = sm(unallocated),
    missing = sm(missing)
  ) %>%
  mutate(mean_value = (produced4cons+consumedFprod)/2,
         missing = (produced4cons-mean_value)*-1) %>% 
  setDT()
  
  m1 <- calc(df)
  m2 <- cl(df)
  m22 <- cl(df2)
  
  # feed flow to total slaughter weight
  # feed <- melt(m1, id.vars = "type",
  #              measure.vars = c("feed", "grazed"))
  # feed <- upData(feed, rename = .q(variable = source, type = target))
  
  # first flow types to slaughter
  first <- m1[,.(source = type, value = total_weight)]
  first[, target := "slaughter" ]
  
  # second flow from slaughter
  second <- data.table(
    source = "slaughter",
    target = c("sold", "meat", "offal", "hides", "inedible"), # could include uncertain
    value = c(pluck(m2$sold_weight), pluck(m2$meat), pluck(m2$offal), pluck(m2$hides), pluck(m2$inedible))
  )

  
  # last flow from hides
  # meat, offal to consumed
  # hides to unused and processed
  # processed hides to sold and consumed
  third <- data.table(
    source = c("meat", "offal"),
    target = c("consumed", "consumed"),
    value = c(pluck(m2$meat), pluck(m2$offal))
    ) #
  
  third_rec <- data.table(
    source = c("consumed", "consumed"),
    target = c("recall", "missing"),
    value = c(pluck(meat_rec$mean_value), pluck(meat_rec$missing))
  )
  
  fourth <- data.table(
    source = c("hides","processing", "processing", "hides"),
    target = c("processing", "sold", "unallocated", "unused"),
    value = c(pluck(m22$pprod), pluck(m22$sold2), pluck(m22$missing), pluck(m2$hides)-pluck(m22$hides))
  )
  
  
  # data2 <- rbind(feed, first, second, third, fourth)
  data2 <- rbind(first, second, third, third_rec, fourth)}


df <- copy(mfa_animals)
df2 <- copy(mfa_hides)

data2 <- mfameat(df, df2)
sankey(data2)


## ------------------------------------------------------------------------------------------------------------
df <- copy(mfa_eggs)
mfaeggs <- function(df){
  
egg_rec <- comp.quant2 %>% 
  filter(new_name_ag == "Eggs") %>% 
  mutate(
    unallocated = ifelse(difference < 0, difference *-1, 0), # more produced than consumed, i.e. waste
  ) %>% 
  select(group, zone, produced4cons, consumedFprod, unallocated) %>%
  group_by(group) %>% # ignore zone for now
  summarise(
    produced4cons = sm(produced4cons),
    consumedFprod = sm(consumedFprod),
    unallocated = sm(unallocated)
  ) %>%
  mutate(mean_value = (produced4cons+consumedFprod)/2,
         unallocated = produced4cons-mean_value) %>% 
  setDT()
  
e1 <- calc(df)
  
data4 <- data.table(
    source = c(
      #"feed","grazed", 
      "poultry",
      "eggs", "eggs", "eggs",
      "consumed", "consumed"),
    target = c(
      #"poultry", "poultry",
      "eggs",
      "sold", "consumed", "unallocated",
      "recall", "unallocated"),
    value = c(
      #pluck(e1$feed), pluck(e1$grazed), 
      pluck(e1$produced),
      pluck(e1$sold), pluck(egg_rec$produced4cons), pluck(e1$uncertain),
      pluck(egg_rec$mean_value), pluck(egg_rec$unallocated))
  )
}


df <- copy(mfa_eggs)
data4 <- mfaeggs(df)
sankey(data4)


## ------------------------------------------------------------------------------------------------------------
cmfa <- copy(mfa_crops)
data <- mfacrops(cmfa)

df <- copy(mfa_animals)
df2 <- copy(mfa_hides)
data2 <- mfameat(df, df2)

df <- copy(mfa_milk)
data3 <- mfamilk(df)

df <- copy(mfa_eggs)
data4 <- mfaeggs(df)
mfa <- rbind(data, data2, data3, data4)

upcase <- function(df){
  df <- df %>% 
    mutate_if(is.character, str_to_sentence) %>% 
    mutate_if(is.factor, function(x) str_to_sentence(as.character(x)))
}

mfaw <- mfa %>% 
  upcase() %>% 
  mutate(target = ifelse(target == "Consumed", "Household", target),
         source = ifelse(source == "Consumed", "Household", source),
         target = ifelse(target == "Sold", "Sales", target),
         source = ifelse(source == "Sold", "Sales", source),
         # new groupings - combine targets
         target = ifelse(
           target == "Waste" | target == "Losses" | target == "Inedible" | target == "Unused", "Loss & Waste", target),
         target = ifelse(target == "Recall", "Consumed", target),
         # target = ifelse(
         #   target == "Missing", "Uncertain", target), # keep missing and uncertain separate to distinguish between results from Chapter 3 and 4
         value = as.numeric(value),
         value = round(value/1000,1) # t
         )

write_csv(mfaw, "2_data/results/mfa3b.csv")

sankey(mfaw)


## ------------------------------------------------------------------------------------------------------------
mfacrops <- function(df){
df <- cmfa[!is.na(type)] # households that were "added" for completion, they will probably need a type and item across all df with 0 values to represent the full sample in all dfs - TBD
# df <- df[type != "cashcrops"] # not needed for this one

  c1 <- calc(df)
  c2 <- cl(df)
  
  # replace consumption value with reconciled quantities
  # reconstruct groups - possibly done at item level like with matching - TBD
  c1 <- c1 %>% 
    setDT() %>% 
    filter(produced>0) %>% 
    left_join(select(reconcile, type = group, produced4cons, mean_value), by = "type") %>% 
    mutate(
      disconnect = (produced4cons-mean_value),
      missing_rec = ifelse(disconnect<0, disconnect*-1, 0),
      unallocated_rec = ifelse(disconnect>0, disconnect, 0)# 
    )

  # first flow: harvest
  first <- c1[,. (source = type, value = produced)]
  first[, target := "Produced"]
  
  # second flow: harvest onward
  second <- c1[,.(source = type, 
                  consumed, 
                  sold, 
                  payment,
                  gifts,
                  losses, 
                  stored, 
                  feed, 
                  processing,
                  unallocated,
                  missing)] # this is uncertain partially from the ag survey only
  
  second <- melt(second, id.vars = "source",
                 measure.vars = c("consumed", "sold", "payment", "gifts", "losses", "stored", "feed", "processing", "unallocated", "missing"))
  
  second <- upData(second,
                   rename = .q(variable = target))
  
  # third flow: processing
  third <- data.table(
    source = "processing",
    target = c("sold", "consumed", "waste"),
    value = c(pluck(c2$prodsold), pluck(c2$prodconsumed), pluck(c2$waste))
  )
  
  fourth <- data.table(
    source = "stored",
    target = "seed",
    value  = pluck(c2$seed)
  )

  # recall
  rec <- data.table(
    source = c("consumed", "consumed", "consumed"),
    target = c("recall", "unallocated", "missing"),
    value = c(sm(c1$mean_value)*1000, sm(c1$unallocated_rec)*1000, sm(c1$missing_rec)*1000) # instead of using the mean value I could produce another set without reconciled data and consumedFprod
  )
  
  data <- rbind(second, third, fourth, rec)
  data <- data %>% select(target, source, value)}

# reconcile <- reconcile_zone %>% filter(zone == "Central")
cmfa <- copy(mfa_crops) 
data <- mfacrops(cmfa)
sankey(data)


c1 <- calc(mfa_crops)
  
  # replace consumption value with reconciled quantities
  # reconstruct groups - possibly done at item level like with matching - TBD
  cropc1 <- c1 %>% 
    setDT() %>% 
    filter(produced>0) %>% 
    left_join(select(reconcile, type = group, produced4cons, mean_value), by = "type") %>% 
    mutate(
      disconnect = (produced4cons-mean_value) # 
    )


## ------------------------------------------------------------------------------------------------------------
name <- "Central"

reconcile <- readRDS("2_data/final/reconcile_zone.RDS") %>% 
  filter(zone == name)
# select zone

cmfa <- copy(mfa_crops) %>% 
  filter(zone == name)

data <- mfacrops(cmfa) # name of reconcile file (to be created)

df <- copy(mfa_animals) %>% 
  filter(zone == name)
df2 <- copy(mfa_hides) %>% 
  filter(zone == name)

data2 <- mfameat(df, df2)

df <- copy(mfa_milk) %>% 
  filter(zone == name)

recegg <- reconcile %>% # reconcile_zone
  filter(group == "milk and dairy products") 
data3 <- mfamilk(df)

df <- copy(mfa_eggs) %>% 
  filter(zone == name)
data4 <- mfaeggs(df)
mfa <- rbind(data, data2, data3, data4)


formatmfa <- function(df){
df %>% 
  upcase() %>% 
  mutate(target = ifelse(target == "Consumed", "Household", target),
         source = ifelse(source == "Consumed", "Household", source),
         target = ifelse(target == "Sold", "Sales", target),
         source = ifelse(source == "Sold", "Sales", source),
         # new groupings - combine targets
         target = ifelse(
           target == "Waste" | target == "Losses" | target == "Inedible" | target == "Unused", "Loss & Waste", target),
         target = ifelse(
           target == "Missing", "Uncertain", target),
         value = as.numeric(value)
         ) 
}

mfa <- formatmfa(mfa)
sankey(mfa)


## ------------------------------------------------------------------------------------------------------------
name <- "Central"

reconcile <- readRDS("2_data/final/reconcile_zone.RDS") %>% 
  filter(zone == name)
# select zone

cmfa <- copy(mfa_crops) %>% 
  filter(zone == name)

data <- mfacrops(cmfa) # name of reconcile file (to be created)

df <- copy(mfa_animals) %>% 
  filter(zone == name)
df2 <- copy(mfa_hides) %>% 
  filter(zone == name)

data2 <- mfameat(df, df2)

df <- copy(mfa_milk) %>% 
  filter(zone == name)

recegg <- reconcile %>% # reconcile_zone
  filter(group == "milk and dairy products") 
data3 <- mfamilk(df)

df <- copy(mfa_eggs) %>% 
  filter(zone == name)
data4 <- mfaeggs(df)
central <- rbind(data, data2, data3, data4)

central <- formatmfa(central)
sankey(central)



## ------------------------------------------------------------------------------------------------------------
name <- "Lakes"

reconcile <- readRDS("2_data/final/reconcile_zone.RDS") %>% 
  filter(zone == name)
# select zone

cmfa <- copy(mfa_crops) %>% 
  filter(zone == name)

data <- mfacrops(cmfa) # name of reconcile file (to be created)

df <- copy(mfa_animals) %>% 
  filter(zone == name)
df2 <- copy(mfa_hides) %>% 
  filter(zone == name)

data2 <- mfameat(df, df2)

df <- copy(mfa_milk) %>% 
  filter(zone == name)

recegg <- reconcile %>% # reconcile_zone
  filter(group == "milk and dairy products") 
data3 <- mfamilk(df)

df <- copy(mfa_eggs) %>% 
  filter(zone == name)
data4 <- mfaeggs(df)
lakes <- rbind(data, data2, data3, data4)

lakes <- formatmfa(lakes)
sankey(lakes)


## ------------------------------------------------------------------------------------------------------------
name <- "Southern Highlands"

reconcile <- readRDS("2_data/final/reconcile_zone.RDS") %>% 
  filter(zone == name)
# select zone

cmfa <- copy(mfa_crops) %>% 
  filter(zone == name)

data <- mfacrops(cmfa) # name of reconcile file (to be created)

df <- copy(mfa_animals) %>% 
  filter(zone == name)
df2 <- copy(mfa_hides) %>% 
  filter(zone == name)

data2 <- mfameat(df, df2)

df <- copy(mfa_milk) %>% 
  filter(zone == name)

recegg <- reconcile %>% # reconcile_zone
  filter(group == "milk and dairy products") 
data3 <- mfamilk(df)

df <- copy(mfa_eggs) %>% 
  filter(zone == name)
data4 <- mfaeggs(df)
southhi <- rbind(data, data2, data3, data4)

southhi <- formatmfa(southhi)
sankey(southhi)


## ------------------------------------------------------------------------------------------------------------
name <- "Northern Highlands"

reconcile <- readRDS("2_data/final/reconcile_zone.RDS") %>% 
  filter(zone == name)
# select zone

cmfa <- copy(mfa_crops) %>% 
  filter(zone == name)

data <- mfacrops(cmfa) # name of reconcile file (to be created)

df <- copy(mfa_animals) %>% 
  filter(zone == name)
df2 <- copy(mfa_hides) %>% 
  filter(zone == name)

data2 <- mfameat(df, df2)

df <- copy(mfa_milk) %>% 
  filter(zone == name)

recegg <- reconcile %>% # reconcile_zone
  filter(group == "milk and dairy products") 
data3 <- mfamilk(df)

df <- copy(mfa_eggs) %>% 
  filter(zone == name)
data4 <- mfaeggs(df)
nohi <- rbind(data, data2, data3, data4)

nohi <- formatmfa(nohi)
sankey(nohi)


## ------------------------------------------------------------------------------------------------------------
name <- "Coastal"

reconcile <- readRDS("2_data/final/reconcile_zone.RDS") %>% 
  filter(zone == name)
# select zone

cmfa <- copy(mfa_crops) %>% 
  filter(zone == name)

data <- mfacrops(cmfa) # name of reconcile file (to be created)

df <- copy(mfa_animals) %>% 
  filter(zone == name)
df2 <- copy(mfa_hides) %>% 
  filter(zone == name)

data2 <- mfameat(df, df2)

df <- copy(mfa_milk) %>% 
  filter(zone == name)

recegg <- reconcile %>% # reconcile_zone
  filter(group == "milk and dairy products") 
data3 <- mfamilk(df)

df <- copy(mfa_eggs) %>% 
  filter(zone == name)
data4 <- mfaeggs(df)
coastal <- rbind(data, data2, data3, data4)

coastal <- formatmfa(coastal)
sankey(coastal)

