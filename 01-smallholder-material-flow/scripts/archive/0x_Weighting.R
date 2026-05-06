# Chapter 3a script

# file not in use anymore??

# Weigh data
weighting <- readRDS("2_data/processed/weighting.RDS") # add clusterid for grouping and stats

weights <- function(df){
  # remove any previous weights or clusterids
  df <- weighting[df, on=.(y4_hhid)]
  df <- df %>% select(!starts_with("i."))
}


# Context data
hhfin <- readRDS("2_data/processed/hhfin.RDS")
ex_hhs <- readRDS("2_data/processed/ex_hhs.RDS") #same as nrow(hhfin[status == "excluded"])
exclusions <- readRDS("2_data/processed/exclusions.RDS")
filter <- readRDS("2_data/processed/filter.RDS")

# Quant data
allprod <- read_csv("2_data/processed/allprod.csv")
setDT(allprod)
crop_disp <- readRDS("2_data/processed/crop_disp.RDS")
tree_disp <- readRDS("2_data/processed/tree_disp.RDS")
yieldgaps <- readRDS("2_data/processed/yieldgaps.RDS")

prelost <- readRDS("2_data/processed/prelost.RDS")
allcrops <- readRDS("2_data/processed/allcrops.RDS")

b1 <- readRDS("2_data/processed/b1.RDS")

animals_short <- readRDS("2_data/processed/animals_short.RDS")

# mfadata <- readRDS("2_data/processed/mfadata.RDS") # without ex_hhs and no cashcrops, input for sankey, shoudl be weighted

# remove cashcrops, excluded households, weigh data
allprod <- allprod[type != 'cashcrops']
prelost <- prelost[type!="cashcrops"]
allcrops <- allcrops[type != "cashcrops"]
b1 <- b1[type != "cashcrops"]
tree_disp <- tree_disp[type != "cashcrops"]
crop_disp <- tree_disp[type != "cashcrops"]

filter <- filter[!ex_hhs, on = .(y4_hhid)]
allprod <- allprod[!ex_hhs, on = .(y4_hhid)]
prelost <- prelost[!ex_hhs, on=.(y4_hhid)]
allcrops <- allcrops[!ex_hhs, on = .(y4_hhid)]
b1 <- b1[!ex_hhs, on = .(y4_hhid)]
animals_short <- animals_short[!ex_hhs, on = .(y4_hhid)]
tree_disp <- tree_disp[!ex_hhs, on = .(y4_hhid)]
crop_disp <- crop_disp[!ex_hhs, on = .(y4_hhid)]

# weighted quantities
allprod <- allprod %>% weights() %>% mutate(across(c(produced:consumed), ~. * weight_adj))
allcrops <- allcrops %>%  weights() %>% mutate(across(c(harvest:smd), ~. * weight_adj))
animals_short <- animals_short %>% weights() %>% mutate(across(c(slaughter:all_lost), ~. * weight_adj))
yieldgaps <- yieldgaps %>% weights() %>% mutate(w_yg = YG * weight_adj, w_yp = YP * weight_adj, 
                                                w_area = area_planted_new * weight_adj, w_harvest = total_harvest * weight_adj)
                                                        
# weighted frequencies
prelost <- weights(prelost)
b1 <- b1 %>% weights() %>% mutate(sold = sold*weight_adj)
crop_disp <- crop_disp %>% weights()
tree_disp <- tree_disp %>% weights()
filter <- filter %>% weights()

## GENERAL NAMING AND GROUPING
# create new groups
# should this be based on the mfadata to reduce potential for error?
prodclean <- copy(allprod)
prodclean[, product_new := fcase(
  group == "Crops", type,
  type == "milk" & product == "large ruminants", "Milk (large ruminants)",
  type == "milk" & product == "small ruminants", "Milk (small ruminants)",
  product == "eggs", "eggs",
  type == "slaughter", product
)]

# generate ordered factors, make naming pretty
prodclean$group <- factor(prodclean$group, levels = c("Crops", "Animal products"))
prodclean$product_new <- ordered(prodclean$product_new, levels = c("fruits","grains & cereals", "legumes", "nuts & seeds", "roots & tubers", "vegetables", "spices", "other", "large ruminants", "small ruminants", "poultry", "pigs", "other animals", "Milk (large ruminants)", "Milk (small ruminants)", "eggs"))
prodclean$product_new <- str_to_sentence(prodclean$product_new)

## TABLE AND FIGURE FORMATTING
sct <- function(x) x/1000
scm <- function(x) x/1000000 # scale million (mostly for population)
sc_mt <- function(x) x/1000000000 # scale to million metric ton
m <- 1000000
ht <- 100000
tt <- 10000
t <- 1000

tblfmt <- function(df){
  df %>% 
    opt_align_table_header(align = "left") %>%
    tab_options(
      table.font.size = px(13)
    )
}

