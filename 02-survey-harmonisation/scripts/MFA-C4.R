# MFA

# corrections
# weighing
# validate and normalize
# 4. Sankey format
# 5. Combine

# 1. Load all data
household_ap <- read_csv("data/c4/aggregated_results_apc4.csv") %>% setDT()
household_crops <- read_csv("data/c4/aggregated_results_cropsc4.csv") %>% setDT()
household_meat <- read_csv("data/c4/aggregated_results_meatc4.csv") %>% setDT()
full_overview_hh4 <- read_csv("data/c4/full_overview_hh4.csv") 

incl_3b <- full_overview_hh4 %>% 
  filter(hh_type == "agricultural" & is.na(final_status4)) %>% 
  select(y4_hhid) %>% 
  distinct()

newfoodgr <- readRDS("data/c4/LSMS_items_match_fin.RDS") %>% 
  select(item, type = group) %>% 
  distinct() %>% 
  mutate(item = str_to_lower(item)) %>% 
  filter(!is.na(item))

feed <- readRDS("/Users/vk20281/Library/CloudStorage/OneDrive-UniversityofBristol/03a_simpleMFA/2_data/processed/feed_short.RDS") %>% clear.labels()
feedtbl <- readRDS("data/c3/feedtbl.RDS") %>% clear.labels() %>% 
  mutate(
    product = fcase(
      grepl("eggs", type), "eggs",
      grepl("milk", type), "milk"),
    typenew = case_when(
      type == "milk (small ruminants)" ~ "small ruminants",
      type == "milk (large ruminants)" ~ "large ruminants",
      product == "eggs" ~ "poultry",
      TRUE ~ type # Default case
    )
  ) %>% 
  select(-type) %>% 
  rename(type = typenew)


# 2. Corrections-----
## Crops----
library(dplyr)
library(data.table)

# --- CROPS PIPELINE (NaN and NA guard) ---
crops <- readRDS("data/c3/mfa_crops.RDS") %>%
  select(-type) %>%
  left_join(newfoodgr, by = "item") %>%
  relocate(type, .before = "item") %>%
  dplyr::select(y4_hhid, type, item, sold, consumed, newprocessing, processing:waste) %>%
  group_by(y4_hhid, type) %>%
  summarise(across(where(is.numeric), ~sum(.x, na.rm = TRUE)), .groups="drop") %>%
  rowwise() %>%
  mutate(
    psoldraw = if_else(sold == 0, 0, 1 - prodsold/sold),
    pconsraw = if_else(consumed == 0, 0, 1 - prodconsumed/consumed),
    pconsraw = ifelse(pconsraw < 0, 0, pconsraw),
    prod = if_else(processing == 0, 0, prodproduced/processing),
    psold = if_else(processing == 0, 0, prodsold/processing),
    pcons = if_else(processing == 0, 0, prodconsumed/processing),
    pwaste = if_else(processing == 0, 0, waste/processing)
  ) %>%
  ungroup() %>%
  mutate(across(where(is.numeric), ~replace(., is.na(.) | is.nan(.), 0)))


# --- HOUSEHOLD CROPS CHECKS PIPELINE (NaN and NA guard) ---
household_crops_checks <- household_crops %>%
  dplyr::select(y4_hhid = household_id, value = mean_value, type, destination) %>%
  setDT() %>%
  dcast(
    y4_hhid + type ~ destination,
    value.var = "value"
  ) %>%
  as_tibble() %>%
  mutate(across(where(is.numeric), ~replace(., is.na(.) | is.nan(.), 0))) %>%
  left_join(crops, by = c("y4_hhid", "type")) %>%
  mutate(
    consumedn = consumed * pconsraw,
    soldn = sold * psoldraw,
    processing = newprocessing + consumed - consumedn + sold - soldn,
    prodproduced = processing * prod,
    prodsold = processing * psold,
    prodconsumed = processing * pcons,
    waste = processing * pwaste
  ) %>%
  mutate(
    balanceprocessing = abs(processing - (prodproduced + waste)) < 1e-9,
    balanceproduce = abs(prodproduced - (prodsold + prodconsumed)) < 1e-9,
    balanceconsumed = abs(dest_consumed - (prodconsumed + consumedn)) > 1e-9
  ) %>%
  mutate(across(where(is.numeric), ~replace(., is.na(.) | is.nan(.), 0)))

household_crops_complete <- household_crops_checks %>% 
  inner_join(incl_3b, by = "y4_hhid") %>% 
  select(y4_hhid, type, dest_sold = soldn, dest_consumed = consumedn, dest_gifts, dest_payment, dest_losses, dest_stored, dest_seed, dest_feed, dest_missing, 
         dest_processing = processing, prodsold, prodconsumed, waste)

## Milk----
household_ap_complete <- household_ap %>% 
  dplyr::select(y4_hhid = household_id, type, destination, value = mean_value) %>%
  setDT() %>% 
  dcast(
    y4_hhid + type ~ destination, # Columns to keep as identifiers
    value.var = "value"     # Column to spread across multiple columns
  ) %>% 
  mutate(
    across(is.numeric, ~ replace_na(., 0)),
    dest_prodsold = dest_processing,
    produced = dest_consumed+dest_missing+dest_processing+dest_sold,
    product = ifelse(type == "eggs", "eggs", "milk"),
    type = fcase(
      type == "eggs", "poultry",
      grepl("large", type), "large ruminants",
      grepl("small", type), "small ruminants"
    )
  ) %>% 
  # estimate feed
  left_join(feed, by = c("y4_hhid", "type")) %>% # from appendix
  left_join(feedtbl, by = c("type", "product", "feed1")) %>% 
  mutate(
    need = ifelse(grepl("milk", product), produced*0.7, produced*2.3), # 0.7 for milk, 2.3 for eggs; see fcr table
    grazed = need*grazed,
    feed = need*feed,
    across(is.numeric, ~ replace_na(., 0))
  ) %>% 
  inner_join(incl_3b, by = "y4_hhid") %>% 
  dplyr::select(-feed1, -need) 

## Meat----
mfa_hides <- readRDS("data/c3/mfa_hides.RDS") %>% 
  clear.labels() %>% 
  mutate(type = paste0("slaughter - ", type),
         psold = sold2/hides) %>% 
  dplyr::select(y4_hhid, type, rel_prod, psold)

breakdown <- read_excel("data/c3/breakdown.xlsx", sheet = "conv") %>% 
  setDT() %>% 
  filter(animal != "Beef")

fcr <- breakdown[,.(type, fcr = FCR_A16, ew = EW_A16)]

feedtbl_short <- feedtbl %>% filter(is.na(product))

household_meat_complete <- household_meat %>% 
  dplyr::select(y4_hhid = household_id, type, destination, value = mean_value) %>% 
  setDT() %>% 
  dcast(
    y4_hhid + type ~ destination, # Columns to keep as identifiers
    value.var = "value"     # Column to spread across multiple columns
  ) %>% 
  full_join(mfa_hides, by = c("y4_hhid", "type")) %>% 
  mutate(
    across(is.numeric, ~ replace_na(., 0)),
    prodproduced = dest_hides*rel_prod,
    dest_prodsold = dest_hides*psold,
    dest_prodsold = ifelse(dest_prodsold>prodproduced, prodproduced, dest_prodsold), # no negative missing
    dest_waste = dest_hides-prodproduced, # not all hides processed into hides
    hides_cons = prodproduced-dest_prodsold, # hides produced not sold are consumed
    val = prodproduced-dest_prodsold-dest_waste==dest_hides, # to be done on absolute values
    slaughtered = dest_hides+dest_inedible+dest_meat+dest_missing+dest_offal+dest_sold) %>% 
  dplyr::select(!c(rel_prod, psold, val)) %>% 
  mutate(type = gsub("^slaughter - ", "", type)) %>% 
  left_join(feed, by = c("y4_hhid", "type")) %>% 
  left_join(feedtbl_short, by = c("type", "feed1")) %>% # from appendix
  left_join(fcr) %>% 
  mutate(
    ew = ew*slaughtered,
    need = ew*fcr,
    grazed = need*grazed,
    feed = need*feed,
    across(is.numeric, ~ replace_na(., 0))
  ) %>% 
  inner_join(incl_3b, by = "y4_hhid") %>% 
  dplyr::select(-feed1, -fcr, -ew, -need)

# 3. Weigh data 
meat <- household_meat_complete %>% 
  filter(!is.na(type)) %>% 
  rename_with(~ sub("^dest_", "", .), starts_with("dest_"))

crops <- household_crops_complete %>%
  rowwise() %>% 
  mutate(produced = sum(c_across(starts_with("dest_")))) %>% 
  filter(!is.na(type)) %>% 
  rename_with(~ sub("^dest_", "", .), starts_with("dest_"))

ap <- household_ap_complete %>%
  relocate(product, .after = "type") %>% 
  filter(!is.na(type)) %>% 
  rename_with(~ sub("^dest_", "", .), starts_with("dest_"))

list <- list(
  crops = crops,
  ap = ap,
  meat = meat
)

flows4C4 <- lapply(list, function(df) {
  colnames(df) <- sub("^dest_", "", colnames(df))
  df
})
# used to compare consumption
saveRDS(flows4C4, "data/c4/flows4C4.RDS")

flows4C4_wide <- meat %>% 
  rename(produced = slaughtered) %>% 
  bind_rows(ap, crops)
fwrite(flows4C4_wide, "data/c4/flows4C4_wide.csv")

# checks
flows4C4_wide %>% filter(is.na(produced)) %>% View()
flows4C4_wide %>% filter(is.na(consumed)) %>% select(type) %>% distinct() %>% View()

# to be used to show uncertainty of flows of interest, adjusted to the new sample size and food groups for crops
household_mcsc4 <- fread("data/c4/household_mcsc4.csv")

