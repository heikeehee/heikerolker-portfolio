library(dplyr)
library(readr)
library(tidyr)
library(ggplot2)
library(data.table)

# 1. Load data
shortnames <- read_excel("2_data/reference/shortnames.xlsx")
afe_mopres_hh <- fread("2_data/results/afe_mopres_hh.csv")
boot_results_long <- readRDS("2_data/results/mosaic_boot_results_long.RDS")
# Uncomment and adjust below if you need food group or zone info
hh_grps <- read_csv("2_data/final/hh_grps.csv")
hhA <- read_csv("2_data/files/hhA.csv")
incl_3b <- read_csv("2_data/results/full_overview_hh4.csv") %>% 
  filter(hh_type == "agricultural" & is.na(final_status4)) %>% 
  select(y4_hhid, zone, month) %>% 
  distinct()


LSMS_items_match <- read_csv("2_data/reference/LSMS_items_match.csv")

LSMS_key <- LSMS_items_match %>%
  mutate(
    new_name_ag = ifelse(is.na(new_name_ag), item, new_name_ag),
    new_name_hh = ifelse(is.na(new_name_hh), hh_product, new_name_hh)
  ) %>%
  filter(group != "cashcrops" | is.na(group))

key_ag <- LSMS_key %>%
  select(item, new_name_ag, new_name_hh) %>%
  distinct()

key_hh <- LSMS_key %>%
  select(itemcode = hh_product, new_name_ag, new_name_hh) %>%
  distinct() %>%
  mutate(new_name_ag = replace_na(new_name_ag, "not matched"))

key_items <- LSMS_key %>%
  select(new_name_ag, new_name_hh) %>%
  distinct()

#2. (Optional) Add food group if not present
boot_results_long <- boot_results_long %>%
  left_join(select(hh_grps, group, shortnames), by = c("item" = "shortnames"))

#3. Ensure 'zone' is in afe_mopres_hh (if not, join by y4_hhid)
if (!"zone" %in% names(afe_mopres_hh)) {
  afe_mopres_hh <- afe_mopres_hh %>%
    #left_join(select(hhA, y4_hhid, zone), by = "y4_hhid") %>% 
    inner_join(incl_3b, by = "y4_hhid")
}

# average per afe consumption by food group
group_month <- boot_results_long %>%
  group_by(group, ID, zone) %>% # total annual household/afe
  summarise(
    sum = sum(mean, na.rm = TRUE)/12,
    .groups = "drop"
  ) %>% 
  group_by(group, zone) %>% # mean by group and zone across household/afe
  summarise(
    mean = mean(sum, na.rm = TRUE),
    se = sd(sum, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  ) %>% 
  group_by(group) %>%
  summarise(
    mean_per_afe = mean(mean),
    n = n(),
    se_per_afe = sd(mean) / sqrt(n), # final SE is the SE of the group mean across zone means
    .groups = "drop"
  ) %>% 
  select(-n)

fwrite(group_month, "2_data/results/group_month.csv")

# 4. Compute mean and SE (standard error) of monthly per-AFE consumption for each zone, group, month
zone_group_month <- boot_results_long %>%
  group_by(zone, ID, group, month) %>%
  summarise(total = sum(mean, na.rm = TRUE), .groups = "drop") %>% # total consumption of food group by ID, month
  group_by(zone, group, month) %>%
  summarise(
    mean_per_afe = mean(total, na.rm = TRUE),
    se_per_afe = sd(total, na.rm = TRUE) / sqrt(n()), # Standard error of the mean
    .groups = "drop"
  )

# 4. Compute mean and SE (standard error) of monthly per-AFE consumption for each zone, group, month
zone_item_month <- boot_results_long %>%
  rename(shortnames = item) %>% 
  # Join with shortnames using correct join keys
  left_join(shortnames, by = "shortnames") %>%
  # Join with key_hh using correct join keys
  left_join(key_hh, by = "itemcode") %>%
  group_by(zone, ID, new_name_hh, month, group) %>%
  summarise(total = sum(mean, na.rm = TRUE), .groups = "drop") %>%
  group_by(zone, group, new_name_hh, month) %>%
  summarise(
    mean_per_afe = mean(total, na.rm = TRUE),
    se_per_afe = sd(total, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  )

# 5. Get total AFE population for each zone
zone_pop <- afe_mopres_hh %>%
  setDT() %>% 
  mutate(afe_7d_mo = afe_7d_mo/12,
         afe_all_mo = afe_all_mo/12) %>% 
  group_by(zone) %>%
  summarise(
    n = n(),
    zone_persons = sum(hh_person, na.rm = TRUE),
    zone_total_afe_7d     = sum(afe_7d, na.rm = TRUE),
    zone_total_afe_7d_mo  = sum(afe_7d_mo, na.rm = TRUE),
    zone_total_afe_all_mo = sum(afe_all_mo, na.rm = TRUE),
    zone_total_afe_mean   = mean(c(zone_total_afe_7d, zone_total_afe_7d_mo, zone_total_afe_all_mo)), # mean of the three
    zone_total_afe_sd     = sd(c(zone_total_afe_7d, zone_total_afe_7d_mo, zone_total_afe_all_mo)),   # SD of the three
    .groups = "drop"
  )

# 2. Extrapolate using the mean AFE population and propagate uncertainty
zone_group_month <- zone_group_month %>%
  left_join(zone_pop, by = "zone") %>%
  mutate(
    mean_total = mean_per_afe * zone_total_afe_mean,
    # Propagate uncertainty: SE_total^2 = (se_per_afe * mean(pop))^2 + (mean_per_afe * sd(pop))^2
    se_total = sqrt( (se_per_afe * zone_total_afe_mean)^2 + (mean_per_afe * zone_total_afe_sd)^2 )
  )

# 7. Aggregate to annual: sum means, combine SEs in quadrature (assume months are independent)
zone_group_annual <- zone_group_month %>%
  group_by(zone, group) %>%
  summarise(
    annual_mean = sum(mean_total, na.rm = TRUE), 
    annual_se = sqrt(sum(se_total^2, na.rm = TRUE)),
    .groups = "drop"
  )

# check afe consumption
afe_zone_group <- zone_group_annual %>% 
  left_join(zone_pop, by = "zone") %>% 
  mutate(pp = annual_mean/zone_persons/12,
         afe = annual_mean/zone_total_afe_mean/12)

fwrite(afe_zone_group, "2_data/results/afe_zone_group.csv")


library(dplyr)
library(tidyr)
library(ggplot2)
library(RColorBrewer)

# Assume zone_group_annual and afe_mopres_hh are already loaded as in your previous steps

# 1. Calculate number of unique households per zone
zone_nhh <- afe_mopres_hh %>%
  group_by(zone) %>%
  summarise(n_households = n_distinct(y4_hhid), .groups = "drop")

# 2. Create new zone label: "zone (N=xxx)"
zone_group_annual_labeled <- zone_group_annual %>%
  left_join(zone_nhh, by = "zone") %>%
  mutate(zone_label = paste0(zone, " (N=", n_households, ")"))

fwrite(zone_group_annual_labeled, "2_data/results/zone_group_annual_labeled.csv")

# 3. Plot using Dark2 palette, x = zone_label, fill = group
library(viridis)
n_groups <- length(unique(zone_group_annual_labeled$group))

# Range of total AFE consumption per zone -- APPENDIX
ggplot(zone_group_annual_labeled, aes(x = zone_label, y = annual_mean, fill = group)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_errorbar(aes(ymin = annual_mean - annual_se, ymax = annual_mean + annual_se, group = group),
                position = position_dodge(width = 0.8), width = 0.3, color = "black") +
  scale_fill_viridis_d(option = "turbo", end = 0.95, direction = 1) +
  labs(
    title = "Annual Zone Consumption by Food Group (AFE extrapolation) with Uncertainty",
    x = "Zone (Number of Households)", y = "Annual Total (kg, extrapolated to zone)", fill = "Food Group"
  ) +
  theme_minimal(base_size = 13) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))


library(dplyr)
library(readr)

# Assume boot_results_long and afe_mopres_hh already loaded, and all previous processing done

# 1. Calculate mean and SE per AFE for each group, month, over all zones (i.e., national level)
national_group_month <- boot_results_long %>%
  group_by(ID, group, month) %>%
  summarise(total = sum(mean, na.rm = TRUE), .groups = "drop") %>% # total consumption of food group by ID, month
  group_by(group, month) %>%
  summarise(
    mean_per_afe = mean(total, na.rm = TRUE), # average consumption of food group by month
    se_per_afe = sd(total, na.rm = TRUE) / sqrt(n()), # SE of the mean across all sampled households
    .groups = "drop"
  )

# 2. Get total national AFE
national_afe <- sum(afe_mopres_hh$afe_7d, na.rm = TRUE)

# 3. Extrapolate mean and SE to national level, for each group and month
national_group_month <- national_group_month %>%
  mutate(
    mean_total = mean_per_afe * national_afe,
    se_total = se_per_afe * national_afe
  )

# 4. Aggregate to annual: sum means, combine SEs in quadrature
national_group_annual <- national_group_month %>%
  group_by(group) %>%
  summarise(
    annual_mean = sum(mean_total, na.rm = TRUE),
    annual_se = sqrt(sum(se_total^2, na.rm = TRUE)),
    .groups = "drop"
  )

# 5. View or save results
print(national_group_annual)
write_csv(national_group_annual, "2_data/results/national_group_annual_afe_mean_se.csv")

library(ggplot2)

# Assuming you have already created 'national_group_annual' (see previous step)
# and it has columns: group, annual_mean, annual_se

ggplot(national_group_annual, aes(x = group, y = annual_mean, fill = group)) +
  geom_col(width = 0.7, show.legend = FALSE) +
  geom_errorbar(aes(ymin = annual_mean - annual_se, ymax = annual_mean + annual_se),
                width = 0.3, color = "black") +
  labs(
    title = "National Annual Consumption by Food Group (AFE extrapolation) with Uncertainty",
    x = "Food Group",
    y = "Annual Total (kg, extrapolated to national AFE)"
  ) +
  theme_minimal(base_size = 13) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

