# MFA

# corrections
# weighing
# validate and normalize
# 4. Sankey format
# 5. Combine

# 1. Load all data
household_ap <- read_csv("data/c3/aggregated_results_ap.csv") %>% setDT()
household_crops <- read_csv("data/c3/aggregated_results_crops.csv") %>% setDT()
household_meat <- read_csv("data/c3/aggregated_results_meat.csv") %>% setDT()

household_mcs <- rbind(household_ap, household_crops, household_meat)
fwrite(household_mcs, "data/c3/household_mcs.csv")

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
crops <- readRDS("data/c3/mfa_crops.RDS") %>% # just to determine processing flow
  dplyr::select(y4_hhid, type, item, sold, consumed, newprocessing, processing:waste) %>% 
  group_by(y4_hhid, type) %>% 
  summarise(across(where(is.numeric), ~sum(.x, na.rm = TRUE))) %>% 
  rowwise() %>%
  mutate(
    # to adjust consumed and sold row
    psoldraw = 1-prodsold/sold, # sold once processed and sold subtracted
    pconsraw = 1-prodconsumed/consumed, # consumed once processed and consumed subtracted
    pconsraw = ifelse(pconsraw<0, 0, pconsraw), # cannot be negative, thus all consumed allocated to processing then consumed
    # adjust processing coherence, newprocessing = all not already included in sold/consumed
    prod = prodproduced/processing, # proportion of product from processing
    psold = prodsold/processing, # proportion of processing sold 
    pcons = prodconsumed/processing, # proportion of processing consumed
    pwaste = waste/processing, # proportion of processing wasted
    across(is.numeric, ~ replace_na(., 0))) 


household_crops_checks <- household_crops %>% 
  dplyr::select(y4_hhid = household_id, value = mean_value, type, destination) %>%
  setDT() %>% 
  dcast(
  y4_hhid + type ~ destination, # Columns to keep as identifiers
  value.var = "value"     # Column to spread across multiple columns
) %>% 
  mutate(
    across(is.numeric, ~ replace_na(., 0))) %>% 
  left_join(crops, by = c("y4_hhid", "type")) %>% 
  mutate(
    consumedn = consumed*pconsraw, # raw adjusted by subtracting processed then consumed, only reflects raw now
    soldn = sold*psoldraw,
    processing = newprocessing + consumed-consumedn + sold-soldn,
    # assign processing to sold
    prodproduced = processing * prod,
    prodsold = processing * psold,
    prodconsumed = processing * pcons,
    waste = processing * pwaste) %>% 
  # check balance
  mutate(
    balanceprocessing = abs(processing - (prodproduced + waste)) < 1e-9,
    balanceproduce = abs(prodproduced - (prodsold+prodconsumed)) < 1e-9,
    balanceconsumed = abs(dest_consumed - (prodconsumed+consumedn)) > 1e-9 # checks out
  )

household_crops_complete <- household_crops_checks %>% 
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
  dplyr::select(-feed1, -fcr, -ew, -need)




# 3. Weigh data 
meat_weighted <- household_meat_complete %>% 
  weigh() %>% 
  mutate(across(c(dest_hides:grazed), ~. * weight_adj)) %>%  
  filter(!is.na(type)) %>% 
  dplyr::select(-weight_adj) %>% 
  rename_with(~ sub("^dest_", "", .), starts_with("dest_"))

crops_weighted <- household_crops_complete %>%
  weigh() %>% 
  rowwise() %>% 
  mutate(across(c(dest_sold:waste), ~. * weight_adj),
         produced = sum(c_across(starts_with("dest_")))) %>% 
  filter(!is.na(type)) %>% 
  dplyr::select(-weight_adj) %>% 
  rename_with(~ sub("^dest_", "", .), starts_with("dest_"))

ap_weighted <- household_ap_complete %>%
  weigh() %>% 
  relocate(product, .after = "type") %>% 
  mutate(across(c(dest_consumed:grazed), ~. * weight_adj)) %>%  
  filter(!is.na(type)) %>% 
  dplyr::select(-weight_adj) %>% 
  rename_with(~ sub("^dest_", "", .), starts_with("dest_"))

list <- list(
  crops = crops_weighted,
  ap = ap_weighted,
  meat = meat_weighted
)

weighted_flows <- lapply(list, function(df) {
  colnames(df) <- sub("^dest_", "", colnames(df))
  df
})

saveRDS(weighted_flows, "data/c3/weighted_flows.RDS")

weighted_flows_wide <- meat_weighted %>% 
  rename(produced = slaughtered) %>% 
  bind_rows(ap_weighted, crops_weighted)

fwrite(weighted_flows_wide, "data/c3/weighted_flows_wide.csv")
           
# 4. Organize flows for Sankey, reshape to long

# 5. Normalise data

# 6. Validate
# Sankey shape - source - target

# NORMALIZE FLOWS HERE
# LATER
# Normalize Flows-----
# Normalize flows to calculate percentages

# 
# # Validate that `mean_value` has no missing or invalid data
# if (any(is.na(aggregated_results$mean_value))) {
#   stop("Error: `mean_value` contains missing (NA) values. Please fix the data before normalization.")
# }
# 
# if (any(aggregated_results$mean_value < 0)) {
#   stop("Error: `mean_value` contains negative values. Please fix the data before normalization.")
# }
# 
# # Validation: Ensure normalization sums to 100% for each type
# validation_check <- normalized_flows[
#   , .(total_normalized_flow = sum(normalized_flow, na.rm = TRUE)), by = type
# ]
# 
# if (any(abs(validation_check$total_normalized_flow - 100) > 1e-6)) {
#   stop("Error: Normalized flows do not sum to 100% for some types. Please recheck the data.")
# }
# 
# # Check for missing combinations of type and destination
# cat("\nChecking for missing type-destination combinations...\n")
# all_combinations <- CJ(
#   type = unique(aggregated_results$type),
#   destination = unique(aggregated_results$destination)
# )
# missing_combinations <- all_combinations[
#   !aggregated_results, on = .(type, destination)
# ]
# 
# if (nrow(missing_combinations) > 0) {
#   cat("\nAdding missing combinations with mean_value set to 0...\n")
#   aggregated_results <- merge(
#     all_combinations, aggregated_results, 
#     by = c("type", "destination"), all.x = TRUE
#   )
#   aggregated_results[is.na(mean_value), mean_value := 0]
# }
# 
# # Recalculate normalized flows after adding missing combinations
# cat("\nRecalculating normalized flows...\n")
# 
# # Recalculate normalized flows and retain all relevant columns
# normalized_flows <- aggregated_results[
#   , .(type, destination, normalized_flow = mean_value / sum(mean_value) * 100), by = type
# ]
# 
# # Validate again: Ensure normalization sums to 100% for each type
# cat("\nRe-validating normalized flows...\n")
# validation_check <- normalized_flows[
#   , .(total_normalized_flow = sum(normalized_flow, na.rm = TRUE)), by = type
# ]
# 
# if (any(abs(validation_check$total_normalized_flow - 100) > 1e-6)) {
#   cat("Error: Normalized flows still do not sum to 100% for some types. Please investigate further.\n")
#   print(validation_check[abs(total_normalized_flow - 100) > 1e-6])
#   stop("Normalization issues persist after attempting corrections.")
# } else {
#   cat("All normalized flows now sum to 100%.\n")
# }
# 
# # Save the cleaned and validated results
# output_path <- "data/c3/normalized_flows_crops_fixed.csv"
# if (!dir.exists(dirname(output_path))) {
#   dir.create(dirname(output_path), recursive = TRUE)
# }
# fwrite(normalized_flows, output_path)
# cat(sprintf("Normalized flows saved to '%s'.\n", output_path))
# 
# # ## FOR Sankey-----
# # add feed for animal products 
# # # Required Libraries
# # library(data.table)
# # 
# # # Load simulation results
# # simulation_results <- fread("data/c3/simulation_results_crops.csv")
# # 
# # # Summarize total flows by type and destination
# # sankey_data <- simulation_results[
# #   , .(total_flow = sum(simulated_values, na.rm = TRUE)),
# #   by = .(type, destination)
# # ]
# # 
# # # Format data for Sankey diagram
# # # Assuming you have a `source` column in your data for the origin of the flow
# # sankey_format <- sankey_data[
# #   , .(source = type, target = destination, value = total_flow)
# # ]
# # 
# # # Save the Sankey data to a CSV file for visualization
# # fwrite(sankey_format, "data/c3/sankey_data_crops.csv")
# # 
# # # Output summary to console
# # cat("Sankey data prepared successfully. Saved to 'sankey_data_crops.csv'.\n")
# # print("Summary of Sankey data:")
# # print(sankey_format)