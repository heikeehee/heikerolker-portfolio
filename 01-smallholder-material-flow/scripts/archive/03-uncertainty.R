# Uncertainty

# 1. Load all data
household_mcs <- read_csv(here::here("data", "processed", "01", "household_mcs.csv"))

# Group by type
group_uncertainty <- household_mcs[, .(
  Sum = sum(mean_value),                          # Sum of values
  SD_Sum = sqrt(sum(sd_value^2)),                  # Combined SD of the sum
  CI_Lower = sum(mean_value) - 1.96 * sqrt(sum(sd_value^2)), # Lower bound of 95% CI
  CI_Upper = sum(mean_value) + 1.96 * sqrt(sum(sd_value^2)),
  Percentage_Uncertainty = (sqrt(sum(sd_value^2)) / sum(mean_value)) * 100  # Upper bound of 95% CI
), by = type]

# Same for each flow
flow_uncertainty <- household_mcs[, .(
  Sum = sum(mean_value),                          # Sum of values
  SD_Sum = sqrt(sum(sd_value^2)),                  # Combined SD of the sum
  CI_Lower = sum(mean_value) - 1.96 * sqrt(sum(sd_value^2)), # Lower bound of 95% CI
  CI_Upper = sum(mean_value) + 1.96 * sqrt(sum(sd_value^2)),
  Percentage_Uncertainty = (sqrt(sum(sd_value^2)) / sum(mean_value)) * 100# Upper bound of 95% CI
), by = destination]

system_uncertainty <- household_mcs[, .(
  Sum = sum(mean_value),                          # Sum of values
  SD_Sum = sqrt(sum(sd_value^2)),                  # Combined SD of the sum
  CI_Lower = sum(mean_value) - 1.96 * sqrt(sum(sd_value^2)), # Lower bound of 95% CI
  CI_Upper = sum(mean_value) + 1.96 * sqrt(sum(sd_value^2)),
  Percentage_Uncertainty = (sqrt(sum(sd_value^2)) / sum(mean_value)) * 100# Upper bound of 95% CI
)]

# weighted
mcs_weighted <- household_mcs %>% 
  rename(y4_hhid = household_id) %>%
  weigh() %>% 
  mutate(
    mean_value = mean_value * weight_adj,
    sd_value = sd_value * weight_adj)

fwrite(mcs_weighted, "data/c3/mcs_weighted.csv")

# Group by type
group_uncertainty_weighted <- mcs_weighted[, .(
  Sum = sum(mean_value),                          # Sum of values
  SD_Sum = sqrt(sum(sd_value^2)),                  # Combined SD of the sum
  CI_Lower = sum(mean_value) - 1.96 * sqrt(sum(sd_value^2)), # Lower bound of 95% CI
  CI_Upper = sum(mean_value) + 1.96 * sqrt(sum(sd_value^2)),
  Percentage_Uncertainty = (sqrt(sum(sd_value^2)) / sum(mean_value)) * 100  # Upper bound of 95% CI
), by = type]

# Same for each flow
flow_uncertainty_weighted <- mcs_weighted[, .(
  Sum = sum(mean_value),                          # Sum of values
  SD_Sum = sqrt(sum(sd_value^2)),                  # Combined SD of the sum
  CI_Lower = sum(mean_value) - 1.96 * sqrt(sum(sd_value^2)), # Lower bound of 95% CI
  CI_Upper = sum(mean_value) + 1.96 * sqrt(sum(sd_value^2)),
  Percentage_Uncertainty = (sqrt(sum(sd_value^2)) / sum(mean_value)) * 100# Upper bound of 95% CI
), by = destination]

# Same for each flow
flowgr_uncertainty_weighted <- mcs_weighted[, .(
  Sum = sum(mean_value),                          # Sum of values
  SD_Sum = sqrt(sum(sd_value^2)),                  # Combined SD of the sum
  CI_Lower = sum(mean_value) - 1.96 * sqrt(sum(sd_value^2)), # Lower bound of 95% CI
  CI_Upper = sum(mean_value) + 1.96 * sqrt(sum(sd_value^2)),
  Percentage_Uncertainty = (sqrt(sum(sd_value^2)) / sum(mean_value)) * 100# Upper bound of 95% CI
), by = c("type", "destination")]


system_uncertainty_weighted <- mcs_weighted[, .(
  Sum = sum(mean_value),                          # Sum of values
  SD_Sum = sqrt(sum(sd_value^2)),                  # Combined SD of the sum
  CI_Lower = sum(mean_value) - 1.96 * sqrt(sum(sd_value^2)), # Lower bound of 95% CI
  CI_Upper = sum(mean_value) + 1.96 * sqrt(sum(sd_value^2)),
  Percentage_Uncertainty = (sqrt(sum(sd_value^2)) / sum(mean_value)) * 100# Upper bound of 95% CI
)]
