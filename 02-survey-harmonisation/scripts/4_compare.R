# ------------------------------------------------------------------------------------------------------------
# Combi Match Analysis Script
# This script combines, cleans, aggregates, and checks data for food group production and consumption analysis.
# GAPS are commented as ### GAP: <description> ###
# ------------------------------------------------------------------------------------------------------------

# ------------------------------------------------------------------------------------------------------------
# 0. LIBRARIES
library(readr)
library(tidyverse)
library(data.table)
library(naniar)
library(ggplot2)

# ------------------------------------------------------------------------------------------------------------
# 1. LOAD MAIN DATASETS
# These must be loaded first as they are used in multiple steps below.
hhA <- read_csv("2_data/files/hhA.csv")
fish_consumption <- readRDS("2_data/final/fish_consumption.RDS")

# Define scaling factor 't' (must be set according to your context)
t <- 1000 # e.g., grams to kilograms, or whatever is appropriate

# ------------------------------------------------------------------------------------------------------------
# 2. PREPARE REFERENCE TABLES AND KEYS

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

# ------------------------------------------------------------------------------------------------------------
# 3. FISH DATA CLEANUP AND MATCHING

fish_match1 <- fish_consumption %>%
  mutate(
    produced = fcase(
      tot.unit == "kilogram", tot.quantity,
      tot.unit == "5 kg bag", tot.quantity * 5,
      tot.unit == "10 kg bag", tot.quantity * 10,
      tot.unit == "large basket", tot.quantity * 15,
      tot.quantity == 999, 9999
    ),
    produced = ifelse(is.na(produced), tot.quantity, produced)
  )

fish_match2 <- fish_match1 %>%
  filter(!is.na(item1) & is.na(item2)) %>%
  select(y4_hhid, item = item1, produced, consumed = tot.consumed)

fish_match3 <- fish_match1 %>%
  filter(!is.na(item2) & is.na(item1)) %>%
  select(y4_hhid, item = item2, produced, consumed = tot.consumed)

fish_match4 <- fish_match1 %>%
  filter(!is.na(item2) & !is.na(item1)) %>%
  mutate(produced = produced / 2, consumed = tot.consumed / 2)

fish_match5 <- fish_match1 %>%
  filter(is.na(item2) & is.na(item1)) %>%
  mutate(
    produced = replace_na(produced, 0),
    consumed = replace_na(tot.consumed, 0),
    item1 = replace_na(item1, "fresh fish"),
    item2 = replace_na(item2, "processed fish")
  )

fish_match <- bind_rows(
  fish_match2,
  fish_match3,
  select(fish_match4, y4_hhid, item = item1, produced, consumed),
  select(fish_match4, y4_hhid, item = item2, produced, consumed),
  select(fish_match5, y4_hhid, item = item1, produced, consumed),
  select(fish_match5, y4_hhid, item = item2, produced, consumed)
) %>%
  mutate(
    group = "fish and sea food",
    item = str_to_sentence(item)
  ) %>%
  left_join(select(hhA, y4_hhid, zone), by = "y4_hhid") 

fish_zone <- fish_match %>% 
  group_by(zone, group) %>% 
  summarise(produced4cons = sum(consumed, na.rm = T)) %>% 
  rename(type = group)
# ------------------------------------------------------------------------------------------------------------
# 8. ZONE-LEVEL ANNUAL PRODUCTION AND UNCERTAINTY
# uncertainty
household_mcsc4 <- read_csv("2_data/results/household_mcsc4.csv")

zone_group_production_uncertainty <- household_mcsc4 %>%
  filter(grepl("consumed", destination)) %>% 
  rename(y4_hhid = household_id) %>% 
  left_join(select(hhA, y4_hhid, zone), by = "y4_hhid") %>%
  mutate(
    type = case_when(
      str_detect(type, "eggs") ~ "meat, poultry and eggs",
      str_detect(type, "milk") ~ "milk and dairy products",
      str_detect(type, "ruminant|pig|poultry|animal") ~ "meat, poultry and eggs",
      TRUE ~ type
    )
  ) %>% 
  mutate(type = ifelse(is.na(type), "cashcrops", type)) %>% 
  group_by(zone, type) %>% 
  summarise(
    produced4cons = sum(mean_value, na.rm = T),
    se_4cons = sqrt(sum(sd_value^2, na.rm = T)), # Combine standard deviations in quadrature
    .groups = "drop") %>% 
  bind_rows(fish_zone)

# ------------------------------------------------------------------------------------------------------------
# 9. ZONE-LEVEL COMPARISON OF CONSUMPTION AND PRODUCTION WITH UNCERTAINTY

#zone_group_annual <- read_csv("2_data/results/zone_group_annual.csv") %>% setDT() 

zone_comparison <- zone_group_annual %>% 
  rename(
    consFprod = annual_mean,
    se_Fprod = annual_se) %>% 
  full_join(zone_group_production_uncertainty, by = c("zone", "group" = "type")) %>% 
  setDT()

zone_comparison[, `:=`(
  diff = produced4cons - consFprod,
  se_diff = sqrt(se_Fprod^2 + se_4cons^2)
)]

zone_comparison[] <- lapply(zone_comparison, function(x) if(is.numeric(x)) replace(x, is.na(x), 0) else x)

fwrite(zone_comparison, "2_data/results/zone_comparison.csv")

# Plot zone-level difference with error bars
ggplot(zone_comparison, aes(x = group, y = diff, fill = zone)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_errorbar(
    aes(ymin = diff - se_diff, ymax = diff + se_diff),
    position = position_dodge(width = 0.8), width = 0.3, color = "black"
  ) +
  labs(
    title = "Difference between Consumption and Production by Zone and Food Group",
    x = "Food Group", y = "Difference (Production - Consumption)",
    fill = "Zone"
  ) +
  theme_minimal(base_size = 13) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

## NATIONAL OVERVIEW 
library(dplyr)
library(knitr)
library(kableExtra)

# Aggregate to national totals by food group TABLE 10
national_comparison <- zone_comparison %>%
  group_by(group) %>%
  summarise(
    consFprod = sum(consFprod, na.rm = TRUE),
    se_Fprod = sqrt(sum(se_Fprod^2, na.rm = TRUE)),  # combine SEs in quadrature
    produced4cons = sum(produced4cons, na.rm = TRUE),
    se_4cons = sqrt(sum(se_4cons^2, na.rm = TRUE)),  # combine SEs in quadrature
    .groups = "drop"
  ) %>%
  mutate(
    diff = produced4cons - consFprod,
    se_diff = sqrt(se_Fprod^2 + se_4cons^2),
    consFprod_SE = paste0(round(consFprod, 1), " (±", round(se_Fprod, 1), ")"),
    produced4cons_SE = paste0(round(produced4cons, 1), " (±", round(se_4cons, 1), ")"),
    diff_SE = paste0(round(diff, 1), " (±", round(se_diff, 1), ")"),
    diff_lower = diff - 1.96 * se_diff,
    diff_upper = diff + 1.96 * se_diff,
    diff_CI = paste0(round(diff, 1), " [", round(diff_lower, 1), ", ", round(diff_upper, 1), "]"),
    sig = ifelse(diff_lower > 0, "Production > Consumption",
                 ifelse(diff_upper < 0, "Consumption > Production", "No Significant Difference"))
  ) %>%
  select(
    group,
    "Consumption (±SE)" = consFprod_SE,
    "Production (±SE)" = produced4cons_SE,
    "Difference (±SE)" = diff_SE,
    "95% CI" = diff_CI,
    "Significance" = sig
  )

fwrite(national_comparison, "2_data/results/national_comparison.csv")

national_comparison %>%
  kable("html", escape = FALSE, align = "lcccc") %>%
  kable_styling(full_width = FALSE, bootstrap_options = c("striped", "hover"), font_size = 14) %>%
  column_spec(1, bold = TRUE)

## PER PERSON DIFFERENCE PER YEAR NEW FIGURE 7
zone_comparison2 <- zone_comparison %>%
  left_join(zone_pop %>% select(zone, zone_persons), by = "zone")

zone_comparison2 <- zone_comparison2 %>%
  mutate(
    diff_pp = ifelse(zone_persons > 0, diff / zone_persons, NA_real_),
    se_diff_pp = ifelse(zone_persons > 0, se_diff / zone_persons, NA_real_)
  )

library(ggplot2)
## NEW FIGURE 7
ggplot(zone_comparison2, aes(x = group, y = diff_pp, fill = zone)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_errorbar(
    aes(ymin = diff_pp - se_diff_pp, ymax = diff_pp + se_diff_pp),
    position = position_dodge(width = 0.8),
    width = 0.3, color = "black"
  ) +
  labs(
    title = "Per-person Difference between Consumption and Production by Zone and Food Group",
    x = "Food Group",
    y = "Difference per person (Production - Consumption)",
    fill = "Zone"
  ) +
  theme_minimal(base_size = 13) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) 

fwrite(zone_comparison2,"2_data/results/zone_comparison2.csv")

# COMPARISON TABLES
library(dplyr)
## TABLE 9 AG
zone_monthly_per_afe <- zone_group_production_uncertainty %>%
  left_join(zone_pop %>% select(zone, zone_total_afe_mean, zone_total_afe_sd), by = "zone") %>%
  mutate(
    monthly_per_afe = produced4cons / zone_total_afe_mean,
    se_monthly_per_afe = monthly_per_afe * sqrt( (se_4cons/produced4cons)^2 + (zone_total_afe_sd/zone_total_afe_mean)^2 )
  ) %>%
  select(zone, food_group = type, monthly_per_afe, se_monthly_per_afe) %>% 
  group_by(food_group) %>% 
  summarise(
    monthly_per_afe = mean(monthly_per_afe, na.rm = TRUE)/12,
    se_monthly_per_afe = sqrt(sum(se_monthly_per_afe^2, na.rm = TRUE)) / n()/12, # SE of the mean
    .groups = "drop"
  )


# ------------------------------------------------------------------------------------------------------------
# ZONE LEVEL MFA

flows4C4_wide <- read_csv("2_data/results/flows4C4_wide.csv") %>% setDT()

zone_group_annual_production <- flows4C4_wide %>% 
  left_join(select(hhA, y4_hhid, zone), by = "y4_hhid") %>%
  mutate( 
    type = case_when(
      str_detect(product, "eggs") ~ "meat, poultry and eggs",
      str_detect(product, "milk") ~ "milk and dairy products",
      str_detect(type, "ruminant|pig|poultry|animal") ~ "meat, poultry and eggs",
      TRUE ~ type
    )
  ) %>%
  mutate(type = ifelse(is.na(type), "cashcrops", type)) %>% 
  group_by(zone, type) %>% 
  summarise(across(where(is.numeric), ~sum(., na.rm = TRUE)), .groups = "drop")

mfa_zone <- zone_group_annual %>% 
  rename(consFprod = annual_mean) %>% 
  right_join(zone_group_annual_production, by = c("zone", "group" = "type")) %>%
  mutate(across(where(is.numeric), ~replace_na(., 0))) %>%
  mutate(
    conswaste = (consumed + prodconsumed + meat + offal) - consFprod,
    conswaste_flag = ifelse(conswaste < 0, "negative_waste", "ok"),
    conswaste = pmax(conswaste, 0)  # set negative waste to zero
  )

mfa_zone %>%
  group_by(conswaste_flag) %>%
  summarise(n = n(), .groups = "drop")

fwrite(mfa_zone, "2_data/results/mfa_zone.csv")

# Test function 
crops <- mfa_zone %>% 
  filter(group != "milk and dairy products" & group != "meat, poultry and eggs") %>% 
  rename(type = group)

cons <- mfa_zone %>% 
  filter(group == "milk and dairy products" |
           group == "meat, poultry and eggs") %>% 
  rename(type = group)

ap <- flows4C4_wide %>% 
  left_join(select(hhA, y4_hhid, zone), by = "y4_hhid") %>%
  filter(!is.na(product)) %>% 
  group_by(zone, type, product) %>% 
  summarise(across(where(is.numeric), ~sum(., na.rm = TRUE)), .groups = "drop")

meat <- flows4C4_wide %>%
  left_join(select(hhA, y4_hhid, zone), by = "y4_hhid") %>%
  filter(grepl("ruminant|pigs|animal|poultry", type) & is.na(product)) %>% 
  rename(slaughtered = produced)
  
list <- list(
  crops = crops,
  ap = ap,
  meat = meat,
  cons = cons
)
