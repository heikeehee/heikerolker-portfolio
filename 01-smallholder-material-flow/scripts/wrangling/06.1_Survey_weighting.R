# Adjusted weigthing
library(here)
source(here::here("scripts", "packages.R"))
source(here::here("scripts", "functions.R"))

# read in data
# household weights for all clusters and household types
hh_ids <- read_csv(here::here("data", "processed", "hh_ids.csv"), 
                   col_types = cols(...1 = col_skip())) %>% 
  select(y4_hhid, y4_weights, clusterid) %>% 
  setDT()

# NOTE: hh_type classification now derived from allagids3.csv — ag_ids join superseded.
# Retained for reference in case hh_type source changes upstream.
# agricultural households
# ag_ids <- read_csv("2_data/processed/ag_ids.csv") %>% 
#   select(y4_hhid) %>% 
#   mutate(hh_type = "agricultural") # only refers to crops

# hh_id_overview <- hh_ids %>% 
#   left_join(ag_ids, by = "y4_hhid") %>% 
#   mutate(hh_type = ifelse(is.na(hh_type), "non-agricultural", hh_type)) %>% 
#   setDT()

# info for all agricultural household and the exclusions
hhs_3a <- read_csv(here::here("data", "results", "allagids3.csv")) %>% setDT()
  
# weighting for all households and clusters
weights <- hhs_3a[hh_ids, on = .(y4_hhid)]

write_csv(weights, here::here("data", "results", "allids3.csv")) # update allids with weights

# basic numbers
pop_n <- sum(weights$y4_weights) # total population
agpop_n <- sum(weights$y4_weights[weights$hh_type == "agricultural"], na.rm = TRUE)

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
message("Population represented by included households: ", round(sum(weights$new_weight, na.rm = TRUE)))

# any cluster with no hh?
ex_clus <- weights[n_clus == 0 & hh_type == "agricultural"] # 5 clusters; all of which with 1/8 ag hh

# determine population affected
clusmis <- sum(ex_clus$y4_weights) # 10696.66 households are not represented

# proportion of agricultural households not represented
message("Total population (weighted): ", round(pop_n))
message("Agricultural population: ", round(agpop_n))
message("Unrepresented (excluded clusters): ", round(clusmis))
message("% ag households unrepresented: ", round(clusmis * 100 / agpop_n, 3), "%")

# adjust for missing clusters
agpop <- weights[status == "included"]
# distribute missing cluster weight 
agpop[, n_mis := new_weight/sum(new_weight)*clusmis]
agpop[, weight_adj := new_weight + n_mis]

# check if all ag hhs represented
stopifnot("Adjusted weights do not sum to agricultural population total" =
  isTRUE(all.equal(sum(agpop$weight_adj, na.rm = TRUE), agpop_n)))

weighting <- agpop[,.(y4_hhid, weight_adj, clusterid)]
saveRDS(weighting, here::here("data", "final", "weighting.RDS"), compress = T)

# overview for all (agricultural) households
hh_ids_full <- read_csv(here::here("data", "processed", "hh_ids.csv"), 
                        col_types = cols(...1 = col_skip()))

# Overview of all households
hhs_3a <- hhs_3a %>% 
  left_join(select(agpop, y4_hhid, weight_adj), by = "y4_hhid") %>% 
  full_join(select(hh_ids_full, y4_hhid, y4_weights), by = "y4_hhid") # add any additional information required for chapter write-up(s)

write_csv(hhs_3a, here::here("data", "results", "hhs_3a.csv"))
