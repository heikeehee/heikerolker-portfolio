## ------------------------------------------------------------------------------------------------------------
library(naniar)


## ------------------------------------------------------------------------------------------------------------
LSMS_key <- LSMS_items_match %>% # comes from 03_Descriptives
  mutate(
    new_name_ag = ifelse(is.na(new_name_ag), item, new_name_ag),
    new_name_hh = ifelse(is.na(new_name_hh), itemcode, new_name_hh)
  ) %>% 
  filter(group != "cashcrops" | is.na(group))

# key for agricultural items
key_ag <- LSMS_key %>% 
  select(item, new_name_ag, new_name_hh) %>% 
  unique() # add fish: "fresh fish" and "processed fish"

# key for household items
key_hh <- LSMS_key %>% 
  select(itemcode, new_name_ag, new_name_hh) %>% 
  unique() %>% 
  mutate(new_name_ag = ifelse(is.na(new_name_ag), "not matched", new_name_ag))


key_items <- LSMS_key %>% 
  select(new_name_ag, new_name_hh) %>% 
  unique()


## ------------------------------------------------------------------------------------------------------------
fish_consumption <- readRDS("2_data/final/fish_consumption.RDS")
# prepare fish for matching
fish_match1 <- fish_consumption %>% 
  mutate(
    produced = fcase(
      tot.unit == "kilogram", tot.quantity,
      tot.unit == "5 kg bag", tot.quantity * 5,
      tot.unit == "10 kg bag", tot.quantity * 10,
      # assumptions
      tot.unit == "large basket", tot.quantity * 15,
      # tot.unit == "piece", 9999, # TBD in relation to consumption if unit match might still be helpful
      # tot.unit == "other (specify)", 9999, # see above
      # tot.unit == "dozen/bundle", 9999,
      tot.quantity == 999, 9999 # clearer its not a real value when taking sums
      ),
    produced = ifelse(is.na(produced), tot.quantity, produced) # or solution above TBD
    # not necessary for consumed, only contains kilogram and other
  )

# only item 1
fish_match2 <- fish_match1 %>% 
  filter(!is.na(item1) & is.na(item2)) %>% 
  select(y4_hhid, item = item1, produced, consumed = tot.consumed) 

# only item 2
fish_match3 <- fish_match1 %>% 
  filter(!is.na(item2) & is.na(item1)) %>% 
  select(y4_hhid, item = item2, produced, consumed = tot.consumed) 

# both item 1 and item 2
fish_match4 <- fish_match1 %>% 
  filter(!is.na(item2) & !is.na(item1)) %>% 
  mutate(
    produced = produced/2,
    consumed = tot.consumed/2)

# neither, thus 0
fish_match5 <- fish_match1 %>% 
  filter(is.na(item2) & is.na(item1)) %>% 
  mutate(
    produced = ifelse(is.na(produced), 0, produced),
    consumed = ifelse(is.na(tot.consumed), 0, tot.consumed),
    item1 = ifelse(is.na(item1), "fresh fish", item1),
    item2 = ifelse(is.na(item2), "processed fish", item2)
    )
    
# bind all
fish_match <- fish_match2 %>% 
  rbind(fish_match3) %>% 
  rbind(select(fish_match4, y4_hhid, item = item1, produced, consumed)) %>% 
  rbind(select(fish_match4, y4_hhid, item = item2, produced, consumed)) %>% 
  rbind(select(fish_match5, y4_hhid, item = item1, produced, consumed)) %>% 
  rbind(select(fish_match5, y4_hhid, item = item2, produced, consumed)) %>% 
  mutate(
    group = "fish and sea food",
    item = str_to_sentence(item)
  ) %>% 
  left_join(select(hhA, y4_hhid, zone))

fwrite(fish_match, "2_data/final/fish_match.csv")


## ------------------------------------------------------------------------------------------------------------
# 1) list of all items produced & consumed
# rename to algin
comp_agri <- production %>%
  # add fish 
  plyr::rbind.fill(fish_match) %>% 
  # fish_consumption, tot.consumed, unit.cons, item1, item2
  ungroup() %>% 
  # change item names for different aggregation level
  left_join(key_ag) %>% 
  group_by(y4_hhid, new_name_ag, new_name_hh, group, zone) %>% # added group and zone to derive comp.quant2, all matched?
  summarise(
    produced = sum(produced),
    consumed = sum(consumed)
  ) %>% 
  ungroup() %>% 
  filter(!is.na(new_name_ag)) # those are the dogs, donkeys, ginger and bilimbi

miss_var_summary(comp_agri)
# comp_agri %>% filter(is.na(new_name_hh)) %>% select(item) %>% unique()
# Ginger & Bilimbi


## ------------------------------------------------------------------------------------------------------------
# 2) list of all items consumed from production
comp_recall <- sevendrecall %>% 
  ungroup() %>% 
  # select(y4_hhid, itemcode, quant, produced, group) %>% 
  left_join(key_hh) %>% 
  group_by(y4_hhid, new_name_hh, new_name_ag, group) %>% 
  summarise(
    quant = sum(quant),
    consfprod = sum(produced),
    purchased = sm(purch),
    gifts = sm(gifts)
  ) %>% 
  ungroup()

miss_var_summary(comp_recall)
# comp_recall %>% filter(is.na(new_name_ag)) %>% select(itemcode) %>% unique()


## ------------------------------------------------------------------------------------------------------------
# Match items based on new less granular names
compare_items <- comp_agri %>% 
  full_join(comp_recall, by = c("new_name_hh", "y4_hhid", "new_name_ag", "group")) %>%  # revise join when happy with match key
  mutate_if(is.numeric , replace_na, 0)

# any duplicates -> 1
compare_items %>% select(y4_hhid, new_name_ag, new_name_hh) %>% unique() 
miss_var_summary(compare_items) # as above ginger, bilimbi

compare_items %>% filter(is.na(zone)) %>% View() # zone is missing from items that only appear in hh survey and are not matched

# comparison based on 1
compare_results1 <- compare_items %>% 
  filter(!is.na(new_name_ag)) %>%  # TBD could be cashcrops
  mutate(
    outcome_cons = fcase(
      consumed == 0 & quant == 0, "Not consumed",
      consumed == 0 & consfprod == 0, "Never consumed from production",
      consumed == 0 & consfprod > 0, "Consumed in household survey",
      consumed > 0 & consfprod == 0, "Consumed in agricultural survey",
      consumed > 0 & consfprod > 0, "Always consumed"),
    outcome_prod = fcase(
      consfprod > 0 & produced == 0, "No production but consumed",
      produced > 0 & consumed == 0 & consfprod > 0, "Production available but only consumed in recall",
      produced == 0 & quant > 0 & consfprod > 0, "Consumed but no production available"),
    source = fcase(
      grepl("Never", outcome_cons) & quant == 0, "Not consumed",
      grepl("Never", outcome_cons) & purchased > 0 & gifts == 0, "Purchase",
      grepl("Never", outcome_cons) & purchased == 0 & gifts > 0, "Gifts",
      grepl("Never", outcome_cons) & purchased > 0 & gifts > 0, "Purchase & gifts"
    )
  )

saveRDS(compare_results1, "2_data/final/compare_results1.RDS")

write_csv(compare_results1, "2_data/results/compare_results1.csv")

table(compare_results1$outcome_cons)

miss_var_summary(compare_results1)

hhonly <- compare_results1 %>% filter(outcome_cons == "Consumed in household survey" & outcome_prod=="Not produced but consumed") %>% nrow() 
all <- compare_results1 %>% filter(outcome_cons != "Never consumed from production") %>% nrow()

hhonly*100/all


## ------------------------------------------------------------------------------------------------------------
# Understanding "Consumed in household survey"
# consumed on recall only but not produced
inhhonly <- compare_results1 %>% 
  filter(outcome_cons == "Consumed in household survey" & outcome_prod == "Not produced but consumed") 

inhhonly %>% 
  select(y4_hhid) %>% 
  unique()
# in 1096/1149, across 685 households

# items most often affected -> add food groups?
table(inhhonly$new_name_ag)

inhhonly %>% 
  group_by(group) %>% 
  summarise(
    count = n()
  )


## ------------------------------------------------------------------------------------------------------------
key_ext <- LSMS_key %>% 
  select(item, itemcode) %>% 
  unique() %>% 
  mutate(
    item = ifelse(is.na(item), "no match", item),
    itemcode = ifelse(is.na(itemcode), "no match", itemcode)
  )

comp_agriextended <- production %>%
  ungroup() %>% 
  # change item names for different aggregation level
  left_join(key_ext) %>% 
  left_join(select(sevendrecall, y4_hhid, itemcode, quant, consfprod = produced), by = c("y4_hhid", "itemcode"))
# how it should look like, TBD what to do with this


## ------------------------------------------------------------------------------------------------------------
# will not run as based on script following this one -> moved from 04 where it should be
# detailed comparison with the matching done in next file
comp.agri2 <- comp_agri %>% 
  group_by(zone, new_name_ag, new_name_hh, group) %>% 
  summarise(
    producedtots = sum(produced),
    produced4cons = sum(consumed)
  ) %>% 
  ungroup()

comp.boot2 <- readRDS("2_data/final/boot4comp.RDS") %>% 
  left_join(key_hh) %>% 
  group_by(zone, new_name_hh, new_name_ag) %>% 
  summarise(
    consumedFprod = sum(meanafe) # consumption estimate based on the mean AFE value
  ) %>% 
  ungroup()

comp.quant2 <- comp.agri2 %>% 
  full_join(comp.boot2, by = c("zone", "new_name_ag", "new_name_hh")) %>% 
  mutate(
    # data in tonne
    produced4cons = produced4cons/t, # ag data
    consumedFprod = consumedFprod/t, # hh data
    # percentage difference consumed - produced
    difference = consumedFprod - produced4cons) %>% 
  setDT() %>% 
  rd()

comp.quant2[, perc_dif := (consumedFprod - produced4cons) / ((consumedFprod + produced4cons)/2) * 100]
comp.quant2[, perc_dif := ifelse(produced4cons>0 & consumedFprod==0, 100, perc_dif)]
comp.quant2[, perc_dif := ifelse(produced4cons==0 & consumedFprod==0, 0, perc_dif)]


comp.quant2[, mean_value := (produced4cons+consumedFprod)/2]
comp.quant2$row_stdev <- apply(comp.quant2[,6:7],1,sd)

comp.agri2
comp.boot2
comp.quant2

write_csv(comp.quant2, "2_data/results/comp.quant2.csv")

# number of households for each zone - this needs to be producing households -> too much effort?
nhh_zone <- miss_mo %>% 
  summarise(across(is.numeric, sum)) %>% 
  setDT() %>% 
  melt() %>% 
  filter(variable != "month") %>% 
  rename(zone = variable, nhh = value)

comp.quant2flourish <- comp.quant2 %>% 
  filter(!grepl("fish", group)) %>% # no quantitative matching possible
  filter(!is.na(group)) %>% 
  mutate(group = str_to_sentence(group)) %>% 
  filter(!is.na(perc_dif)) %>%  # removes unmatched
  left_join(nhh_zone) %>% 
  mutate(
    diff_hh = difference/nhh
  )

write_csv(comp.quant2flourish, "2_data/results/comp.quant2flourish.csv")

comp.quant2flourish2 <- comp.quant2 %>% 
  filter(!grepl("fish", group)) %>% # no quantitative matching possible
  filter(!is.na(group)) %>% 
  mutate(group = str_to_sentence(group)) %>% 
  filter(!is.na(perc_dif)) %>%  # removes unmatched
  group_by(group) %>% 
  summarise(across(is.numeric, sum)) %>% 
  mutate(
    perc_dif = (consumedFprod - produced4cons) / ((consumedFprod + produced4cons)/2) * 100,
  )

write_csv(comp.quant2flourish2, "2_data/results/comp.quant2flourish2.csv")

# collapse ignoring zones
comp.quant2nat <- comp.quant2 %>% 
  group_by(group, new_name_ag) %>% 
  summarise(
    producedtots = sm(producedtots),
    produced4cons = sm(produced4cons),
    consumedFprod = sm(consumedFprod),
    mn.diff = mn(difference), # average across
    mn.per.diff = mn(perc_dif)
  ) %>% 
  mutate(
    mean_value = (produced4cons+consumedFprod)/2,
    perc_dif = (consumedFprod - produced4cons) / ((consumedFprod + produced4cons)/2) * 100, # new estimate
    difference = produced4cons - consumedFprod
  ) 
comp.quant2nat$row_stdev <- apply(comp.quant2nat[,4:5],1,sd)

comp.quant2nat <- comp.quant2nat %>% 
  select(group, new_name_ag, producedtots, produced4cons, consumedFprod, difference, perc_dif, mean_value, row_stdev, mn.diff, mn.per.diff) %>% 
  rd()

write_csv(comp.quant2nat, "2_data/results/comp.quant2nat.csv")


## ------------------------------------------------------------------------------------------------------------
comp.quant2flourish2 <- comp.quant2 %>% 
  filter(!grepl("fish", group)) %>% # no quantitative matching possible
  filter(!is.na(group)) %>% 
  mutate(group = str_to_sentence(group)) %>% 
  filter(!is.na(perc_dif)) # removes unmatched

