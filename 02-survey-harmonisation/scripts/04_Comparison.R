## ------------------------------------------------------------------------------------------------------------
library(readr)
library(tidyverse)


## ----eval=FALSE----------------------------------------------------------------------------------------------
# # use from descriptives.
# # names matching
# hh_names_match <- read_csv("2_data/reference/LSMS_items_match.csv") %>%
#   filter(!is.na(hh_product)) %>%
#   filter(!(item == "sweet potatoes cover")) %>%  # this is correct but messes up the code below
#   unique()  # misses duplicates
# 
# # Household items
# hh_names <- hh_names_match %>%
#   select(itemcode = hh_product, group) %>% # to match on new name ag with ag file
#   filter(!is.na(itemcode)) %>%
#   filter(!is.na(group) & group != "slaughter") %>%
#   select(itemcode, group) %>%
#   unique() %>%  # should be 61
#   mutate(itemcode = str_to_sentence(itemcode))
# 
# 
# # Agricultural items
# ag_names <- hh_names_match %>%
#   select(item, group) %>% # to match on new name hh with hh file
#   filter(!is.na(item)) %>%
#   unique() %>%  # no remaining duplicates
#   mutate(item = str_to_sentence(item))


## ------------------------------------------------------------------------------------------------------------
comp.boot <- readRDS("2_data/final/boot4comp.RDS") %>% 
  group_by(zone, group) %>% 
  summarise(
    consumedFprod = sum(meanafe) # any uncertainty measure from 3a that can be added?
  )


## ------------------------------------------------------------------------------------------------------------
# from descriptives files
comp.prod <- production %>% 
  group_by(zone, group) %>% 
  summarise(
    produced4cons = sum(consumed) # any uncertainty measure from 3a that can be added?
  )

comp.prod


## ------------------------------------------------------------------------------------------------------------
comp.quant <- comp.prod %>% 
  full_join(comp.boot, by = c("zone", "group")) %>% 
  mutate(
    produced4cons = produced4cons/t, # ag data
    consumedFprod = consumedFprod/t, # hh data
    difference = consumedFprod - produced4cons) %>% 
  rd() %>% 
  setDT()

comp.quant[, perc_dif := (consumedFprod - produced4cons) / produced4cons * 100]

# difference in length from beverages (home brews not clear what based on), and seafood (currently ignored in agriculture)

View(comp.quant)

write_csv(comp.quant, "2_data/results/comp.quant.csv")



## ------------------------------------------------------------------------------------------------------------
prod_boot_total <- readRDS("2_data/final/prod_boot_total.RDS")
 
# production data
comp.prod3 <- production %>% 
  group_by(y4_hhid, group) %>% 
  summarise(
    produced4cons = sum(consumed) # any uncertainty measure from 3a that can be added?
  ) %>% 
  ungroup()

comp.bt3 <- readRDS("2_data/results/prd.bt.annual.food.groups.RDS") %>% 
  rename(consumedFprod = quant)

comp.quant3 <- comp.bt3 %>% 
  filter(group != "fish and sea food" & group != "beverages") %>%  # not available in production
  full_join(comp.prod3) %>% 
  mutate(
    produced4cons = ifelse(is.na(produced4cons), 0, produced4cons) # food group does not appear in production survey
  ) %>% 
  left_join(select(hhA, y4_hhid, zone)) %>% 
  mutate(
    difference = consumedFprod - produced4cons,
    perc_diff = (consumedFprod - produced4cons) / ((consumedFprod + produced4cons)/2) * 100
  )


## ------------------------------------------------------------------------------------------------------------
# household level analysis
comp3.hhlevel <- comp.quant3 %>% 
  group_by(zone, group) %>% 
  summarise(
    tot.bt.cons = sum(consumedFprod), # total consumption for Sankey
    tot.prod = sum(produced4cons),
    mn.diff = mn(difference),
    sd.diff = sd(difference),
    md.diff = median(difference),
    # mn.perc = mn(perc_dif) # mmh wouldnt this be the most accurate
  ) %>% 
  ungroup() %>% 
  mutate(
    perc.dif.zone = (tot.prod - tot.bt.cons) / ((tot.prod + tot.bt.cons)/2) * 100) %>% 
  rd()

comp3.hhlevel %>%
  ggplot(aes(y=perc.dif.zone, x=group)) +
    geom_bar (stat="identity",position = position_dodge(0.9)) +
    scale_y_continuous(breaks = seq(-200,200,25),limits = c(-200,200)) +
    theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust=1)) +
  facet_wrap(~zone)



## ------------------------------------------------------------------------------------------------------------
comp3.zone <- comp3.hhlevel %>% 
  group_by(group) %>% 
  summarise(
    mn.perc = mn(perc.dif.zone) # only, for now.
  )
  
comp3.hhlevel %>%
  ggplot(aes(y=mn.perc, x=group)) +
    geom_bar(stat="identity",position = position_dodge(0.9)) +
    scale_y_continuous(breaks = seq(-200,200,50),limits = c(-200,200)) +
    theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust=1)) 
# looks odd...

