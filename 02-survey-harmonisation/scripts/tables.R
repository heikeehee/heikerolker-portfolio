library(tidyverse)

# TABLE 4
flows4C4_wide <- read_csv("2_data/results/flows4C4_wide.csv")
afe_mopres_hh <- read_csv("2_data/results/afe_mopres_hh.csv")

pretab1 <- flows4C4_wide %>% 
  left_join(afe_mopres_hh, by = "y4_hhid") %>%
  mutate(
      consumed = ifelse(
        is.na(meat) | is.na(offal),
        consumed, # leave as-is if NA in source columns
        ifelse(meat >= 0, offal + meat, consumed)),# refer to estimated edible weight
    prodconsumed = replace_na(prodconsumed, 0), # replace NA with 0 for production consumed
    type = case_when(
      str_detect(product, "eggs") ~ "meat, poultry and eggs",
      str_detect(product, "milk") ~ "milk and dairy products",
      str_detect(type, "ruminant|pig|poultry|animal") ~ "meat, poultry and eggs",
      TRUE ~ type
    ),
    producer = ifelse(produced>0, 1, 0),
    consumer = ifelse(consumed>0,1,0),
  ) %>%
  mutate(
    consumed = consumed + prodconsumed, # total consumption is sum of consumed and production consumed
  ) %>% 
  filter(type != "cashcrops") 

tab1 <- pretab1 %>%
  group_by(type) %>% 
  summarise(
      totalcons = sum(consumed, na.rm = TRUE) + sum(prodconsumed, na.rm = TRUE), # total household consumption
      totalprod = sum(produced, na.rm = TRUE), # total household production
      perc = totalcons / totalprod * 100,
      producer = sum(producer),
      consumer = sum(consumer),
      p_hh = consumer*100/producer,
      prod = mean(produced),
      cons = mean(consumed),
      p = cons*1000*100/prod,
      meancons = mean(totalcons)/12, # average monthly consumption per household
      meanperc = mean(perc, na.rm=T), # average percentage consumed
      hh_person = sum(hh_person, na.rm = T), # total persons consuming
      totalcons = sum(totalcons), # total consumption
      percapitacons = totalcons/hh_person/12) # per capita monthly availability based on consumption value only

# tab4: household consumption based on bootstrap
afe_zone_group <- read_csv("2_data/results/afe_zone_group.csv")

library(dplyr)

tab4 <- afe_zone_group %>%
  mutate(
    zone_total_afe_se = zone_total_afe_sd / sqrt(n),
    per_person_mean = annual_mean / zone_total_afe_mean,
    per_person_se = abs(per_person_mean) * sqrt(
      (annual_se / annual_mean)^2 +
        (zone_total_afe_se / zone_total_afe_mean)^2
    ),
    per_person_mean_monthly = per_person_mean / 12,
    per_person_se_monthly = per_person_se / 12
  )

tab4_group <- tab4 %>%
  group_by(group) %>%
  summarise(
    n = n(),
    avg_per_person_mean = mean(per_person_mean, na.rm = TRUE), # annual
    avg_per_person_se = sqrt(sum(per_person_se^2, na.rm = TRUE)) / n,
    avg_per_person_mean_monthly = mean(per_person_mean_monthly, na.rm = TRUE),
    avg_per_person_se_monthly = sqrt(sum(per_person_se_monthly^2, na.rm = TRUE)) / n,
    .groups = "drop"
  )

print(tab4_group)



# TABLE x: total per person & household consumption based on agricultural survey
hhA <- read_csv("2_data/files/hhA.csv")

# --- Data Preparation and Calculation ---
pretab7 <- pretab1 %>%
  group_by(y4_hhid) %>% 
  summarise(
    consumed = sum(consumed, na.rm = TRUE) # total consumption per household
  )

tab7 <- pretab7 %>%
  left_join(afe_mopres_hh, by = "y4_hhid") %>%
  left_join(hhA, by = "y4_hhid") %>%
  mutate(
    conafeall = if_else(is.na(afe_all) | afe_all == 0, NA_real_, consumed / afe_all),
    conafe7d = if_else(is.na(afe_7d) | afe_7d == 0, NA_real_, consumed / afe_7d),
    con7dpres = if_else(is.na(afe_7d_mo) | afe_7d_mo == 0, NA_real_, consumed / (afe_7d_mo / 12)),
    conallpres = if_else(is.na(afe_all_mo) | afe_all_mo == 0, NA_real_, consumed / (afe_all_mo / 12)),
    mean_afe_annual = rowMeans(across(c(conafeall, conafe7d, con7dpres, conallpres)), na.rm = TRUE),
    consumed_mo = consumed / 12,
    mean_afe_mo = mean_afe_annual / 12
  )

zone_summary <- tab7 %>%
  group_by(zone) %>%
  summarise(
    n = n(),
    mean_total_household = mean(consumed_mo, na.rm = TRUE),
    disp_total_household = if (n() > 1) sd(consumed_mo, na.rm = TRUE) / sqrt(n()) else sd(consumed_mo, na.rm = TRUE),
    mean_afe = mean(mean_afe_mo, na.rm = TRUE),
    disp_afe = if (n() > 1) sd(mean_afe_mo, na.rm = TRUE) / sqrt(n()) else sd(mean_afe_mo, na.rm = TRUE),
    .groups = "drop"
  )

# Rename columns for clarity: sd if n==1, se gif n>1
zone_summary <- zone_summary %>%
  mutate(
    disp_total_household_label = ifelse(n > 1, "se", "sd"),
    disp_afe_label = ifelse(n > 1, "se", "sd")
  ) %>%
  select(
    zone,
    n,
    mean_total_household,
    disp_total_household,
    disp_total_household_label,
    mean_afe,
    disp_afe,
    disp_afe_label
  )

print(zone_summary)

# tab2: annual/monthly consumption agricultural survey by food group with uncertainty
tab2 <- pretab1 %>%
  left_join(hhA, by = "y4_hhid") %>% 
  mutate(
    conafeall = if_else(is.na(afe_all) | afe_all == 0, NA_real_, consumed / afe_all),
    conafe7d = if_else(is.na(afe_7d) | afe_7d == 0, NA_real_, consumed / afe_7d),
    con7dpres = if_else(is.na(afe_7d_mo) | afe_7d_mo == 0, NA_real_, consumed / (afe_7d_mo / 12)),
    conallpres = if_else(is.na(afe_all_mo) | afe_all_mo == 0, NA_real_, consumed / (afe_all_mo / 12)),
    mean_afe_annual = rowMeans(across(c(conafeall, conafe7d, con7dpres, conallpres)), na.rm = TRUE),
    consumed_mo = consumed / 12,
    mean_afe_mo = mean_afe_annual / 12
  )

zone_summarytab2 <- tab2 %>%
  group_by(type, zone) %>%
  summarise(
    n = n(),
    mean_total_household = mean(consumed_mo, na.rm = TRUE),
    disp_total_household = if (n() > 1) sd(consumed_mo, na.rm = TRUE) / sqrt(n()) else sd(consumed_mo, na.rm = TRUE),
    mean_afe = mean(mean_afe_mo, na.rm = TRUE),
    disp_afe = if (n() > 1) sd(mean_afe_mo, na.rm = TRUE) / sqrt(n()) else sd(mean_afe_mo, na.rm = TRUE),
    .groups = "drop"
  )

# Rename columns for clarity: sd if n==1, se if n>1
zone_summarytab2 <- zone_summarytab2 %>%
  mutate(
    disp_total_household_label = ifelse(n > 1, "se", "sd"),
    disp_afe_label = ifelse(n > 1, "se", "sd")
  ) %>%
  select(
    zone,
    type,
    n,
    mean_total_household,
    disp_total_household,
    disp_total_household_label,
    mean_afe,
    disp_afe,
    disp_afe_label
  )

print(zone_summarytab2)

tab2 <- zone_summarytab2 %>%
  group_by(group = type) %>%
  summarise(
    n = sum(n),
    mean_total_household = mean(mean_total_household, na.rm = TRUE),
    # Combine SEs for independent means: sqrt(sum(se^2)) / number of zones
    mean_total_household_se = sqrt(sum((disp_total_household[disp_total_household_label == "se"]^2), na.rm = TRUE)) / sum(disp_total_household_label == "se"),
    mean_total_household_sd = sqrt(mean((disp_total_household[disp_total_household_label == "sd"]^2), na.rm = TRUE)),
    mean_afe = mean(mean_afe, na.rm = TRUE),
    mean_afe_se = sqrt(sum((disp_afe[disp_afe_label == "se"]^2), na.rm = TRUE)) / sum(disp_afe_label == "se"),
    mean_afe_sd = sqrt(mean((disp_afe[disp_afe_label == "sd"]^2), na.rm = TRUE)),
    .groups = "drop"
  ) %>%
  mutate(
    disp_total_household = ifelse(!is.na(mean_total_household_se), mean_total_household_se, mean_total_household_sd),
    disp_total_household_label = ifelse(!is.na(mean_total_household_se), "se", "sd"),
    disp_afe = ifelse(!is.na(mean_afe_se), mean_afe_se, mean_afe_sd),
    disp_afe_label = ifelse(!is.na(mean_afe_se), "se", "sd")
  ) %>%
  select(
    group, n, mean_total_household, disp_total_household, disp_total_household_label,
    mean_afe, disp_afe, disp_afe_label
  )

fwrite(tab2, "2_data/results/consumption_agricultural_survey.csv")

print(tab2)