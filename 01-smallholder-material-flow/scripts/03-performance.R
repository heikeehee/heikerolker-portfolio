# Load Required Libraries
library(data.table)
library(dplyr)
library(ggplot2)
library(readr)

# --------------------------------------------
# PART 1: AGGREGATE RESULTS AND CALCULATE SYSTEM UNCERTAINTY
# --------------------------------------------

aggregated_results <- household_mcs

# Calculate Total Variance and Uncertainty
aggregated_results[, variance := sd_value^2]  # Assuming `sd_value` exists in the data
total_variance <- sum(aggregated_results$variance, na.rm = TRUE)
total_uncertainty <- sqrt(total_variance)

# Output Total System Uncertainty
cat("Total System Uncertainty (SD):", total_uncertainty, "\n")

# --------------------------------------------
# PART 2: GOODNESS OF FIT ANALYSIS
# --------------------------------------------

# Read Observed Data
if (!file.exists("data/c3/mfa_crops_cleaned.csv") || !file.exists("data/c3/mfa_ap_cleaned.csv")) {
  stop("Error: One or more input files for observed data are missing.")
}

mfa_crops_cleaned <- fread("data/c3/mfa_crops_cleaned.csv") %>%
  dplyr::select(y4_hhid, type, produced, starts_with("dest")) %>%
  melt(
    id.vars = c("y4_hhid", "type"),
    variable.name = "destination",
    value.name = "observed_value"
  )

mfa_ap_cleaned <- fread("data/c3/mfa_ap_cleaned.csv") %>%
  dplyr::select(y4_hhid, type, produced, starts_with("dest")) %>%
  melt(
    id.vars = c("y4_hhid", "type"),
    variable.name = "destination",
    value.name = "observed_value"
  )

mfa_meat_cleaned <- fread("data/c3/mfa_meat_cleaned.csv") %>%
  dplyr::select(y4_hhid, type, produced, starts_with("dest")) %>%
  melt(
    id.vars = c("y4_hhid", "type"),
    variable.name = "destination",
    value.name = "observed_value"
  )


observed_data <- rbindlist(list(mfa_crops_cleaned, mfa_ap_cleaned, mfa_meat_cleaned))

fwrite(observed_data, "data/c3/observed_data.csv")

# Read Simulated Data
simulated_data <- household_mcs

# Aggregate Simulated Data
simulated_means <- simulated_data[, .(mean_value = mean(mean_value, na.rm = TRUE)), by = .(type, destination)]

# Merge Observed and Simulated Data
comparison <- merge(observed_data, simulated_means, by = c("type", "destination"), all = TRUE)

# Calculate Goodness-of-Fit Metrics
comparison[, residual := observed_value - mean_value]
rmse <- sqrt(mean(comparison$residual^2, na.rm = TRUE))
mae <- mean(abs(comparison$residual), na.rm = TRUE)
r_squared <- 1 - (sum(comparison$residual^2, na.rm = TRUE) /
                    sum((comparison$observed_value - mean(comparison$observed_value, na.rm = TRUE))^2, na.rm = TRUE))

# Output Goodness-of-Fit Metrics
cat("RMSE:", rmse, "\n")
cat("MAE:", mae, "\n")
cat("R-squared:", r_squared, "\n")

# --------------------------------------------
# PART 3: DIAGNOSTIC PLOTS
# --------------------------------------------

# Calculate Observed Means
observed_mean <- observed_data %>%
  group_by(type, destination) %>%
  summarise(observed_mean = mean(observed_value, na.rm = TRUE), .groups = "drop")

# Calculate Observed Means
simulated_means <- simulated_data %>%
  group_by(type, destination) %>%
  summarise(simulated_mean = mean(mean_value, na.rm = TRUE), .groups = "drop")

# Ensure log-scale compatibility
valid_data <- merge(observed_mean, simulated_means, by = c("type", "destination"), all = TRUE) %>%
  filter(observed_mean > 0 & simulated_mean > 0)

# Log-scale plot
ggplot(valid_data, aes(x = log(observed_mean), y = log(simulated_mean))) +
  geom_point(alpha = 0.7, color = "blue") +
  geom_abline(intercept = 0, slope = 1, color = "red", linetype = "dashed") +
  labs(
    title = "Log-Scale Observed vs Predicted Flows",
    x = "Log Observed Flows",
    y = "Log Predicted Flows"
  ) +
  theme_minimal()

# --------------------------------------------
# END OF SCRIPT
# --------------------------------------------