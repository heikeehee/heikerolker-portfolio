# Adjusted weigthing
library(haven)
library(data.table)
library(tidyverse)

# read in data
# household weights for all clusters and household types
hh_ids <- read_csv("2_data/processed/hh_ids.csv", 
                   col_types = cols(...1 = col_skip())) %>% 
  select(y4_hhid, y4_weights, clusterid) %>% 
  setDT()

# agricultural households
# ag_ids <- read_csv("2_data/processed/ag_ids.csv") %>% 
#   select(y4_hhid) %>% 
#   mutate(hh_type = "agricultural") # only refers to crops

# hh_id_overview <- hh_ids %>% 
#   left_join(ag_ids, by = "y4_hhid") %>% 
#   mutate(hh_type = ifelse(is.na(hh_type), "non-agricultural", hh_type)) %>% 
#   setDT()

# info for all agricultural household and the exclusions
hhs_3a <- read_csv("2_data/results/allagids3.csv") %>% setDT()
  
# weighting for all households and clusters
weights <- hhs_3a[hh_ids, on = .(y4_hhid)]

write_csv(weights, "2_data/results/allids3.csv") # update allids with weights

# basic numbers
pop_n <- sum(weights$y4_weights) # total population
agpop_n <- weights %>% filter(hh_type == "agricultural")
agpop_n <- sum(agpop_n$y4_weights)  # number of agricultural households

# total weight of ag hhs in cluster
weights[, ag_weight := ifelse(is.na(hh_type), 0, y4_weights)]
weights[, ag_cluswt := sum(ag_weight), by=clusterid]

# count of ag hhs in cluster -> not necessary
weights[, n_ag := ifelse(is.na(hh_type), 0,1)]
weights[, N_ag := sum(n_ag), by=clusterid] 

# count hhs of cluster included
weights[, n_incl := ifelse(status == "excluded" | is.na(status), 0, 1)]
# total hh included in cluster
weights[, n_clus := sum(n_incl), by=clusterid]

# calculate new cluster weights for included hh only
weights[, new_weight := ifelse(status == "excluded" | is.na(status), NA, ag_cluswt/n_clus)]

# population represented
sum(weights$new_weight, na.rm = T) # 7117789

# any cluster with no hh?
ex_clus <- weights[n_clus == 0 & hh_type == "agricultural"] # 5 clusters; all of which with 1/8 ag hh

# determine population affected
clusmis <- sum(ex_clus$y4_weights) # 10696.66 households are not represented

# proportion of agricultural households not represented
sum(ex_clus$y4_weights)*100/agpop_n # 0.1500552% of ag households are not represented

# adjust for missing clusters
agpop <- weights[status == "included"]
# distribute missing cluster weight 
agpop[, n_mis := new_weight/sum(new_weight)*clusmis]
agpop[, weight_adj := new_weight + n_mis]

# check if all ag hhs represented
sum(agpop$weight_adj, na.rm = T) == agpop_n

weighting <- agpop[,.(y4_hhid, weight_adj, clusterid)]
saveRDS(weighting, "2_data/final/weighting.RDS", compress = T)

# overview for all (agricultural) households
hh_ids <- read_csv("2_data/processed/hh_ids.csv", 
                   col_types = cols(...1 = col_skip()))

# Overview of all households
hhs_3a <- hhs_3a %>% 
  left_join(select(agpop, y4_hhid, weight_adj), by = "y4_hhid") %>% 
  full_join(select(hh_ids, y4_hhid, y4_weights), by = "y4_hhid") # add any additional information required for chapter write-up(s)

write_csv(hhs_3a, "2_data/results/hhs_3a.csv")
