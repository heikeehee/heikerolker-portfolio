# ---- Libraries ----
library(data.table)
library(tidyverse)

# ---- Assume boot_ap is already loaded and is a wide data.frame/data.table with columns: y4_hhid, zone, month, [items] ----

# ---- Completeness checks ----
if (!all(c("y4_hhid", "zone", "month") %in% names(boot_ap))) {
  stop("boot_ap must contain columns: y4_hhid, zone, month")
}
value_cols <- setdiff(names(boot_ap), c("y4_hhid", "zone", "month"))
if (length(value_cols) == 0) stop("No value columns found in boot_ap.")

zones <- unique(boot_ap$zone)
months <- sort(unique(boot_ap$month))
if (length(zones) == 0 | length(months) == 0) stop("No zones or months found in boot_ap.")

if (any(is.na(boot_ap$zone)) | any(is.na(boot_ap$y4_hhid))) {
  stop("NA values found in household or zone in boot_ap.")
}

# ---- Data to long ----
long_dt <- melt(as.data.table(boot_ap),
                id.vars = c("zone", "month", "y4_hhid"),
                variable.name = "item", value.name = "value")

# ---- Compute mean and sd for each zone-month-item ----
zone_month_stats <- long_dt[, .(
  mean = mean(value, na.rm=TRUE),
  sd = sd(value, na.rm=TRUE),
  n = .N
), by = .(zone, month, item)]

# ---- Find all expected zone-month-item combinations ----
all_combos <- CJ(zone = zones, month = months, item = unique(long_dt$item))
zone_month_stats_full <- all_combos[zone_month_stats, on = c("zone", "month", "item")]

# ---- 1. Fill missing zone-month-item with mean of that item across all months in the same zone ----
zone_item_means <- zone_month_stats[, .(zone_mean = mean(mean, na.rm=TRUE)), by = .(zone, item)]
zone_month_stats_full1 <- copy(zone_month_stats_full)
zone_month_stats_full1[is.na(mean), `:=`(
  mean = zone_item_means[.SD, on = .(zone, item), zone_mean],
  sd = NA_real_,
  n = 0
)]

# For reporting, fill any remaining NA mean (if any) with overall mean for that item (rare, if zone is missing all data)
item_means <- zone_month_stats[, .(overall_item_mean = mean(mean, na.rm=TRUE)), by = .(item)]
zone_month_stats_full1[is.na(mean), mean := item_means[.SD, on = .(item), overall_item_mean]]

# ---- 2. Fill missing zone-month-item with mean for the missing month across all zones (if still NA) ----
zone_month_stats_full2 <- copy(zone_month_stats_full)
month_item_means <- zone_month_stats[, .(month_mean = mean(mean, na.rm=TRUE)), by = .(month, item)]
zone_month_stats_full2[is.na(mean), `:=`(
  mean = month_item_means[.SD, on = .(month, item), month_mean],
  sd = NA_real_,
  n = 0
)]
zone_month_stats_full2[is.na(mean), mean := item_means[.SD, on = .(item), overall_item_mean]]

# ---- Final completeness checks ----
if (any(is.na(zone_month_stats_full1$mean))) {
  warning("Still NA means in zone_month_stats_full1 after all fills.")
}
if (any(is.na(zone_month_stats_full2$mean))) {
  warning("Still NA means in zone_month_stats_full2 after all fills.")
}

# ---- Output has mean and sd for each item per month and zone ----
saveRDS(zone_month_stats_full1, "2_data/appendix/zone_month_item_means_fill_by_zone.RDS")
saveRDS(zone_month_stats_full2, "2_data/appendix/zone_month_item_means_fill_by_month.RDS")


library(data.table)
library(tidyverse)
library(readxl)

# ---- Prepare input month-item means (NATIONAL, not grouped by zone) ----
value_cols <- setdiff(names(boot_ap), c("y4_hhid", "zone", "month"))
long_dt <- melt(as.data.table(boot_ap),
                id.vars = c("zone", "month", "y4_hhid"),
                variable.name = "item", value.name = "value")

# NATIONAL reference: mean across all zones for each month-item
library(dplyr)

# Find households with any NA or Inf in 'value'
hhid_with_na <- long_dt %>%
  group_by(y4_hhid) %>%
  filter(any(is.na(value))) %>%
  pull(y4_hhid) %>%
  unique()

hhid_with_inf <- long_dt %>%
  group_by(y4_hhid) %>%
  filter(any(is.infinite(value))) %>%
  pull(y4_hhid) %>%
  unique()

# Combine the two sets
hhid_to_remove <- union(hhid_with_na, hhid_with_inf)

# Remove these households from long_dt
long_dt_clean <- long_dt %>%
  filter(!y4_hhid %in% hhid_to_remove)

# Check the result
cat("Number of households removed:", length(hhid_to_remove), "\n")
cat("Number of rows in cleaned data:", nrow(long_dt_clean), "\n")


input_means_national <- long_dt_clean[, .(
  mean_input = mean(value, na.rm=TRUE),
  sd_input = sd(value, na.rm=TRUE),
  n_input = .N
), by = .(month, item)]

# For later merging, create all possible combinations of zone, month, item
zones <- unique(boot_ap$zone)
months <- sort(unique(boot_ap$month))
all_combos <- CJ(zone = zones, month = months, item = unique(long_dt$item))

# Merge national means onto all (zone, month, item) -- so each zone gets the same national reference
input_means_full <- merge(
  all_combos,
  input_means_national,
  by = c("month", "item"),
  all.x = TRUE
)

# FIGURE 5, seasonal variation based on recall only
# Join group info
long_dt_grouped <- merge(long_dt_clean, hh_grps, by.x = "item", by.y = "shortnames", all.x = TRUE)

hh_month_group <- long_dt_grouped[, .(
  hh_group_total = sum(value, na.rm = TRUE)
), by = .(y4_hhid, month, group)]

group_month_summary <- hh_month_group[, .(
  mean_consumption = mean(hh_group_total, na.rm = TRUE),
  sd_consumption   = sd(hh_group_total, na.rm = TRUE),
  n                = .N,
  se_consumption   = if (.N > 1) sd(hh_group_total, na.rm = TRUE) / sqrt(.N) else NA_real_
), by = .(month, group)]

group_month_summary

library(ggplot2)

# FIGURE 5
ag_group_month_summary <- group_month_summary %>%
  inner_join(incl_3b)
ggplot(ag_group_month_summary, aes(x = month, y = mean_consumption, color = group, group = group)) +
  geom_line(linewidth = 1) +
  geom_ribbon(aes(ymin = mean_consumption - se_consumption,
                  ymax = mean_consumption + se_consumption,
                  fill = group), alpha = 0.18, color = NA) +
  labs(title = "Mean Monthly Household Consumption by Food Group",
       x = "Month",
       y = "Mean Consumption per Household",
       color = "Food Group",
       fill = "Food Group") +
  theme_minimal() +
  theme(legend.position = "bottom")

fwrite(ag_group_month_summary, "2_data/results/ag_group_month_summary.csv")

# ---- Load the four methods (zone-level) ----
zone_month_stats_full1 <- readRDS("2_data/appendix/zone_month_item_means_fill_by_zone.RDS")   # fill by zone
zone_month_stats_full2 <- readRDS("2_data/appendix/zone_month_item_means_fill_by_month.RDS")  # fill by month
boot_hh_mean_within_long  <- readRDS("2_data/results/mosaic_boot_within_zones_results_long.RDS")  %>% setDT()   # bootstrap within zone
boot_hh_mean_across_long  <- readRDS("2_data/results/mosaic_boot_across_zones_results_long.RDS")   %>% setDT() # bootstrap across zones

# ---- Summarize bootstrap results to mean and sd for each zone, month, item ----
boot_within_summary <- boot_hh_mean_within_long[, .(
  mean_within = mean(.SD$mean, na.rm = TRUE),
  sd_within = mean(.SD$se, na.rm = TRUE)
), by = .(zone, month, item)]
boot_across_summary <- boot_hh_mean_across_long[, .(
  mean_across = mean(.SD$mean, na.rm = TRUE),
  sd_across = mean(.SD$se, na.rm = TRUE)
), by = .(zone, month, item)]

# ---- Merge all results for comparison ----
compare_dt <- reduce(list(
  input_means_full, # national reference: mean_input, n_input (same for each zone)
  zone_month_stats_full1[, .(zone, month, item, mean_fill_zone = mean, sd_fill_zone = sd)],
  zone_month_stats_full2[, .(zone, month, item, mean_fill_month = mean, sd_fill_month = sd)],
  boot_within_summary,
  boot_across_summary
), ~ merge(.x, .y, by = c("zone", "month", "item"), all = TRUE))

# ---- Add a flag for which zone-month-items were missing in the input ----
compare_dt[, missing_in_input := is.na(mean_input)]

# ---- Optional: Order columns for clarity ----
setcolorder(compare_dt, c("zone", "month", "item", "mean_input", "n_input", "missing_in_input",
                          "mean_fill_zone", "sd_fill_zone", "mean_fill_month", "sd_fill_month",
                          "mean_within", "sd_within", "mean_across", "sd_across"))

# ---- Save for analysis ----
saveRDS(compare_dt, "2_data/appendix/compare_all_methods_vs_input.RDS")

# ---- Add food group mapping and summarise by group ----
hh_grps <- readRDS("2_data/final/LSMS_items_match_fin.RDS")
shortnames <- read_excel("2_data/reference/shortnames.xlsx") %>%
  mutate(itemcode = stringr::str_to_sentence(itemcode))

hh_grps <- hh_grps %>%
  select(itemcode, group) %>%
  filter(!is.na(itemcode), group != "slaughter") %>%
  arrange(itemcode) %>%
  left_join(shortnames, by = "itemcode") %>%
  distinct(itemcode, .keep_all = TRUE)

compare_dt <- compare_dt %>%
  left_join(select(hh_grps, group, shortnames), by = c("item" = "shortnames"))

# Ensure sd_input exists for pivoting
if(!"sd_input" %in% names(compare_dt)) {
  compare_dt$sd_input <- NA_real_
}

# Pivot to long for method and value separation
compare_long <- compare_dt %>%
  pivot_longer(
    cols = c(mean_input, mean_fill_zone, mean_fill_month, mean_within, mean_across,
             sd_input, sd_fill_zone, sd_fill_month, sd_within, sd_across),
    names_to = c(".value", "method"),
    names_pattern = "(mean|sd)_(.*)"
  )

# Summarise by group: sum of means for all items in the group
# Propagate uncertainty as sqrt(sum(sd^2)) per method, group, zone, month
compare_group <- compare_long %>%
  filter(!is.na(group)) %>%
  group_by(zone, month, group, method) %>%
  summarise(
    mean = sum(mean, na.rm = TRUE),
    sd = sqrt(sum(sd^2, na.rm = TRUE)),
    n_items = n(),
    missing_in_input = any(missing_in_input)
  ) %>%
  ungroup()

compare_group <- compare_group %>%
  mutate(
    mean = ifelse(is.infinite(mean) | is.nan(mean), NA, mean),
    sd   = ifelse(is.infinite(sd) | is.nan(sd), NA, sd)
  )

# Save grouped summary
saveRDS(compare_group, "2_data/appendix/compare_grouped_consumption.rds")

# ---- 4. Visual comparison monthly - Appendix ----
ggplot(compare_group, aes(x = month, color = method, group = method)) +
  geom_line(aes(y = mean), linewidth = 1) +
  geom_ribbon(aes(ymin = mean - sd, ymax = mean + sd, fill = method), alpha = 0.15, color = NA) +
  facet_grid(group ~ zone, scales = "free_y", switch = "y") +
  labs(title = "Food Group Mean Consumption by Method, Zone, and Month",
       y = "Sum of Mean Consumption (per group)", x = "Month") +
  theme_minimal() +
  scale_color_brewer(type = "qual", palette = "Dark2") +
  scale_fill_brewer(type = "qual", palette = "Dark2") +
  scale_x_continuous(breaks = scales::pretty_breaks(), labels = scales::number_format(accuracy = 1)) +
  theme(
    strip.text.y.right = element_text(angle = 90, hjust = 0.5, vjust = 0.5, face = "bold"), # food group labels vertical, right
    strip.placement = "outside", # ensures strips are outside the panel
    legend.position = "bottom",  # legend at bottom
    legend.title = element_text(face = "bold"),
    legend.text = element_text(size = 11),
    plot.margin = margin(5.5, 55, 5.5, 5.5) # extra space on right for group labels
  )


# Calculate total annual consumption and uncertainty for each method, zone
annual_totals <- compare_group %>%
  filter(!is.infinite(mean), !is.nan(mean), !is.infinite(sd), !is.nan(sd)) %>%
  group_by(zone, method) %>%
  summarise(
    total_kg = sum(mean, na.rm = TRUE),
    total_sd = sqrt(sum(sd^2, na.rm = TRUE)),
    .groups = "drop"
  )

# Separate input (reference) and methods
annual_input <- annual_totals %>% filter(method == "input") %>%
  select(zone, total_kg_input = total_kg, total_sd_input = total_sd)

annual_methods <- annual_totals %>% filter(method != "input")

# Join to get differences vs. input
annual_diff <- annual_methods %>%
  left_join(annual_input, by = "zone") %>%
  mutate(
    diff_kg = total_kg - total_kg_input,
    diff_sd = sqrt(total_sd^2 + total_sd_input^2) # propagate uncertainty
  )

# Visual comparison: Bar plot of difference vs input, with error bars: FIGURE 1 TOTAL ANNUAL
# Number the methods for display
annual_diff <- annual_diff %>%
  arrange(method) %>%
  mutate(
    method_num = as.numeric(factor(method)) # assign numeric labels to methods
  )

ggplot(annual_diff, aes(x = factor(method_num), y = diff_kg, color = factor(method_num))) +
  geom_point(size = 4, position = position_dodge(width = 0.6)) +
  geom_errorbar(aes(ymin = diff_kg - diff_sd, ymax = diff_kg + diff_sd),
                width = 0.2, position = position_dodge(width = 0.6)) +
  facet_wrap(~ zone, scales = "free_y") +
  scale_color_brewer(type = "qual", palette = "Dark2",
                     labels = paste0(unique(annual_diff$method_num), ". ", unique(annual_diff$method)),
                     name = "Method") +
  labs(
    title = "Difference in Total Annual Consumption vs Input",
    x = "Method",
    y = "Difference to Input (kg/year)"
  ) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    legend.title = element_text(face = "bold"),
    legend.text = element_text(size = 11)
  )

fwrite(annual_diff, "2_data/results/annual_diff.csv")

library(dplyr)
library(ggplot2)

# 1. Aggregate to national level: sum over zones for each group and method: FIGURE 2 FOOD GROUPS ANNUAL
library(dplyr)

# annual_group_national <- compare_group %>% # makes difference appear small, some error here
#   group_by(group, method) %>%
#   summarise(
#     total_kg = mean(mean, na.rm = TRUE),
#     total_sd = sqrt(sum(sd^2, na.rm = TRUE)) / n(),  # <-- divide by n()
#     .groups = "drop"
#   )

annual_group_national <- compare_group %>% # now directlu comparable to fig 4.2
  group_by(group, method) %>%
  summarise(
    total_kg = sum(mean, na.rm = TRUE),           # sum over zones & months
    total_sd = sqrt(sum(sd^2, na.rm = TRUE)),      # propagate once only
    .groups = "drop"
  )

# 2. Input totals for each food group (national)
annual_input_national <- annual_group_national %>% 
  filter(method == "input") %>%
  select(group, total_kg_input = total_kg, total_sd_input = total_sd)

# 3. Join and compute difference to input
annual_group_diff_nat <- annual_group_national %>%
  filter(method != "input") %>%
  left_join(annual_input_national, by = "group") %>%
  mutate(
    diff_kg = total_kg - total_kg_input,
    diff_sd = sqrt(total_sd^2 + total_sd_input^2)
  )

# 4. Number methods for compact x-axis/legend
annual_group_diff_nat <- annual_group_diff_nat %>%
  arrange(method) %>%
  mutate(
    method_num = as.numeric(factor(method)),
    method_label = as.character(method_num)
  )

# 5. All food groups in one grouped bar plot
ggplot(annual_group_diff_nat, aes(x = group, y = diff_kg, fill = method_label)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_errorbar(aes(ymin = diff_kg - diff_sd, ymax = diff_kg + diff_sd),
                width = 0.2, position = position_dodge(width = 0.8)) +
  scale_fill_brewer(type = "qual", palette = "Dark2",
                    labels = paste0(unique(annual_group_diff_nat$method_num), ". ", unique(annual_group_diff_nat$method)),
                    name = "Method") +
  labs(
    title = "Difference in Annual Consumption per Food Group vs Input (National)",
    x = "Food Group",
    y = "Difference to Input (kg/year)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    legend.title = element_text(face = "bold"),
    legend.text = element_text(size = 11),
    axis.text.x = element_text(angle = 35, hjust = 1)
  )

fwrite(annual_group_diff_nat, "2_data/results/annual_group_diff_nat.csv")

library(dplyr)
library(ggplot2)

# 1. Aggregate to national total by month and method (sum over groups and zones) - FIGURE 3 DIFFERENCES PER MONTH
monthly_national <- compare_group %>%
  group_by(month, method, zone) %>% 
  summarise(
    total = sum(mean, na.rm = TRUE),                    # total for each zone
    total_sd = sqrt(sum(sd^2, na.rm = TRUE)),           # propagated SD for each zone
    .groups = "drop"
  ) %>%
  group_by(month, method) %>%
  summarise(
    total_kg = mean(total, na.rm = TRUE),               # national mean across zones
    total_sd = sqrt(sum(total_sd^2, na.rm = TRUE)) / n(), # uncertainty of the mean
    .groups = "drop"
  )

# 2. Input totals for each month
monthly_input <- monthly_national %>%
  filter(method == "input") %>%
  select(month, total_kg_input = total_kg, total_sd_input = total_sd)

# 3. Join and compute difference to input for each method and month
monthly_diff <- monthly_national %>%
  filter(method != "input") %>%
  left_join(monthly_input, by = "month") %>%
  mutate(
    diff_kg = total_kg - total_kg_input,
    diff_sd = sqrt(total_sd^2 + total_sd_input^2)
  )

# 4. Number methods for compact legend
monthly_diff <- monthly_diff %>%
  arrange(method) %>%
  mutate(
    method_num = as.numeric(factor(method)),
    method_label = as.character(method_num)
  )

# 5. Plot: Line plot with error ribbon, one line per method
# Example: Add a flagged vertical line for month 9, a label, and a smoother

library(ggplot2)
fwrite(monthly_diff, "2_data/results/monthly_diff.csv")

ggplot(monthly_diff, aes(x = month, y = diff_kg, color = method_label, group = method_label)) +
  geom_line(linewidth = 1) +
  geom_ribbon(aes(ymin = diff_kg - diff_sd, ymax = diff_kg + diff_sd, fill = method_label), alpha = 0.18, color = NA) +
  geom_vline(xintercept = 9, linetype = "dashed", color = "red", linewidth = 1) +
  annotate("text", x = 9, y = max(monthly_diff$diff_kg, na.rm = TRUE), label = "Low N in month 9", color = "red", vjust = -0.5, hjust = 0) +
  geom_smooth(aes(group = method_label, color = method_label, fill = method_label), method = "loess", se = FALSE, linetype = "dotted", linewidth = 1, alpha = 0.25, show.legend = FALSE) +
  scale_color_brewer(type = "qual", palette = "Dark2",
                     labels = paste0(unique(monthly_diff$method_num), ". ", unique(monthly_diff$method)),
                     name = "Method") +
  scale_fill_brewer(type = "qual", palette = "Dark2", guide = "none") +
  labs(
    title = "Monthly Difference in National Total Consumption vs Input",
    x = "Month",
    y = "Difference to Input (kg)",
    color = "Method"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    legend.title = element_text(face = "bold"),
    legend.text = element_text(size = 11)
  )

