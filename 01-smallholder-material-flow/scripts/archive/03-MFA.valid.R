
# 



## Validate aggregated results----
# Validation Script for Aggregated Results
# Load aggregated results

# 1. Check for Missing Values
cat("Checking for missing values...\n")
missing_values <- aggregated_results[is.na(mean_value) | is.na(sd_value) | is.na(count)]
if (nrow(missing_values) > 0) {
  cat("Warning: Missing values found in the following rows:\n")
  print(missing_values)
} else {
  cat("No missing values found.\n")
}

# 2. Validate Column Data Types
cat("\nValidating column data types...\n")
str(aggregated_results)  # Check the structure of the data
if (!all(sapply(aggregated_results[, .(mean_value, sd_value, count)], is.numeric))) {
  cat("Error: Non-numeric values found in numeric columns.\n")
} else {
  cat("All numeric columns are valid.\n")
}

# 3. Validate Count Column
cat("\nValidating count column...\n")
if (any(aggregated_results$count < 1)) {
  cat("Warning: Some rows have a simulation count less than 1.\n")
  print(aggregated_results[count < 1])
} else {
  cat("All rows have valid simulation counts.\n")
}

# 4. Validate Standard Deviation
cat("\nValidating standard deviation column...\n")
if (any(aggregated_results$sd_value < 0)) {
  cat("Error: Negative standard deviation values found.\n")
  print(aggregated_results[sd_value < 0])
} else {
  cat("All standard deviation values are valid.\n")
}

# 5. Validate Mean and SD Relationship
cat("\nValidating mean and standard deviation relationship...\n")
if (any(aggregated_results$sd_value > aggregated_results$mean_value)) {
  cat("Warning: Some rows have standard deviation greater than the mean.\n")
  print(aggregated_results[sd_value > mean_value])
} else {
  cat("All rows have valid mean and SD relationships.\n")
}

# 6. Validate Grouping by Type and Destination
cat("\nValidating grouping consistency...\n")
if (anyDuplicated(aggregated_results[, .(type, destination, household_id)]) > 0) {
  cat("Error: Duplicate rows found for type and destination grouping.\n")
  print(aggregated_results[duplicated(aggregated_results[, .(type, destination, household_id)])])
} else {
  cat("No duplicate rows found for type and destination grouping.\n")
}

# 7. Statistical Summary
cat("\nGenerating summary statistics...\n")
summary_stats <- aggregated_results[
  , .(
    total_mean = sum(mean_value, na.rm = TRUE),
    total_sd = sum(sd_value, na.rm = TRUE),
    total_count = sum(count, na.rm = TRUE),
    min_mean = min(mean_value, na.rm = TRUE),
    max_mean = max(mean_value, na.rm = TRUE),
    min_sd = min(sd_value, na.rm = TRUE),
    max_sd = max(sd_value, na.rm = TRUE)
  )
]
print(summary_stats)

# 8. Save Validation Report
cat("\nSaving validation report...\n")
validation_report <- list(
  missing_values = missing_values,
  summary_stats = summary_stats
)
saveRDS(validation_report, "validation_report.rds")
cat("Validation report saved as 'validation_report.rds'.\n")


# AGGREGATE BY GROUP----
fdgrps <- crops %>% 
  dplyr::select(type, item) %>% 
  unique()

aggregated_results <- simulation_results %>% 
  rename(item=type) %>% 
  left_join(fdgrps) 

aggregated_results <- aggregated_results_grps[
  , .(
    mean_value = mean(simulated_values, na.rm = TRUE),
    sd_value = sd(simulated_values, na.rm = TRUE),
    count = .N  # Number of simulations
  ),
  by = .(type, destination)
]

aggregated_results <- simulation_results[
  , .(
    mean_value = mean(simulated_values, na.rm = TRUE),
    sd_value = sd(simulated_values, na.rm = TRUE),
    count = .N  # Number of simulations
  ),
  by = .(type, destination)
]

# Save aggregated results to disk
# fwrite(aggregated_results, "data/c3/aggregated_results_crops.csv")

## Validate aggregated results----
# Validation Script for Aggregated Results
# Load aggregated results

# 1. Check for Missing Values
cat("Checking for missing values...\n")
missing_values <- aggregated_results[is.na(mean_value) | is.na(sd_value) | is.na(count)]
if (nrow(missing_values) > 0) {
  cat("Warning: Missing values found in the following rows:\n")
  print(missing_values)
} else {
  cat("No missing values found.\n")
}

aggregated_results[is.na(sd_value), sd_value := 0]

# 2. Validate Column Data Types
cat("\nValidating column data types...\n")
str(aggregated_results)  # Check the structure of the data
if (!all(sapply(aggregated_results[, .(mean_value, sd_value, count)], is.numeric))) {
  cat("Error: Non-numeric values found in numeric columns.\n")
} else {
  cat("All numeric columns are valid.\n")
}

# 3. Validate Count Column
cat("\nValidating count column...\n")
if (any(aggregated_results$count < 1)) {
  cat("Warning: Some rows have a simulation count less than 1.\n")
  print(aggregated_results[count < 1])
} else {
  cat("All rows have valid simulation counts.\n")
}

# 4. Validate Standard Deviation
cat("\nValidating standard deviation column...\n")
if (any(aggregated_results$sd_value < 0)) {
  cat("Error: Negative standard deviation values found.\n")
  print(aggregated_results[sd_value < 0])
} else {
  cat("All standard deviation values are valid.\n")
}

# 5. Validate Mean and SD Relationship
cat("\nValidating mean and standard deviation relationship...\n")
if (any(aggregated_results$sd_value > aggregated_results$mean_value)) {
  cat("Warning: Some rows have standard deviation greater than the mean.\n")
  print(aggregated_results[sd_value > mean_value])
} else {
  cat("All rows have valid mean and SD relationships.\n")
}

# 6. Validate Grouping by Type and Destination
cat("\nValidating grouping consistency...\n")
if (anyDuplicated(aggregated_results[, .(type, destination, household_id)]) > 0) {
  cat("Error: Duplicate rows found for type and destination grouping.\n")
  print(aggregated_results[duplicated(aggregated_results[, .(type, destination, household_id)])])
} else {
  cat("No duplicate rows found for type and destination grouping.\n")
}

# 7. Statistical Summary
cat("\nGenerating summary statistics...\n")
summary_stats <- aggregated_results[
  , .(
    total_mean = sum(mean_value, na.rm = TRUE),
    total_sd = sum(sd_value, na.rm = TRUE),
    total_count = sum(count, na.rm = TRUE),
    min_mean = min(mean_value, na.rm = TRUE),
    max_mean = max(mean_value, na.rm = TRUE),
    min_sd = min(sd_value, na.rm = TRUE),
    max_sd = max(sd_value, na.rm = TRUE)
  )
]
print(summary_stats)

# 8. Save Validation Report
cat("\nSaving validation report...\n")
validation_report <- list(
  missing_values = missing_values,
  summary_stats = summary_stats
)
saveRDS(validation_report, "validation_report.rds")
cat("Validation report saved as 'validation_report.rds'.\n")

# Normalize Flows by group NOT item -----

# Normalize flows to calculate percentages
aggregated_results[is.na(mean_value), mean_value := 0]
normalized_flows <- aggregated_results[
  , normalized_flow := mean_value / sum(mean_value) * 100, by = type]

# Validate that `mean_value` has no missing or invalid data
if (any(is.na(aggregated_results$mean_value))) {
  stop("Error: `mean_value` contains missing (NA) values. Please fix the data before normalization.")
}

if (any(aggregated_results$mean_value < 0)) {
  stop("Error: `mean_value` contains negative values. Please fix the data before normalization.")
}

# Validation: Ensure normalization sums to 100% for each type
validation_check <- normalized_flows[
  , .(total_normalized_flow = sum(normalized_flow, na.rm = TRUE)), by = type
]

if (any(abs(validation_check$total_normalized_flow - 100) > 1e-6)) {
  stop("Error: Normalized flows do not sum to 100% for some types. Please recheck the data.")
}

# Step 1: Identify problematic types
problematic_types <- validation_check[abs(total_normalized_flow - 100) > 1e-6]
cat("Problematic types where normalized flows do not sum to 100%:\n")
print(problematic_types) # none

# Step 2: Inspect data for problematic types
cat("\nInspecting rows in aggregated_results for problematic types...\n")
problematic_data <- aggregated_results[type %in% problematic_types$type]
print(problematic_data) # none

# Step 3: Check if `mean_value` sums to zero for any problematic type
zero_sums <- aggregated_results[
  , .(total_mean = sum(mean_value, na.rm = TRUE)), by = type
][type %in% problematic_types$type & total_mean == 0]

if (nrow(zero_sums) > 0) {
  cat("\nTypes with zero total mean_value:\n")
  print(zero_sums)
}

# Step 4: Ensure all destinations are present for problematic types
cat("\nChecking for missing destinations in problematic types...\n")
all_combinations <- CJ(
  type = unique(aggregated_results$type),
  destination = unique(aggregated_results$destination)
)
missing_combinations <- all_combinations[
  !aggregated_results, on = .(type, destination)
][type %in% problematic_types$type]

if (nrow(missing_combinations) > 0) {
  cat("\nMissing type-destination combinations:\n")
  print(missing_combinations)
}

# Step 5: Add missing combinations with `mean_value` set to 0
if (nrow(missing_combinations) > 0) {
  cat("\nAdding missing combinations with mean_value set to 0...\n")
  aggregated_results <- merge(
    all_combinations, aggregated_results, 
    by = c("type", "destination"), all.x = TRUE
  )
  aggregated_results[is.na(mean_value), mean_value := 0]
}

# Step 6: Recalculate normalized flows
cat("\nRecalculating normalized flows...\n")
normalized_flows <- aggregated_results[
  , normalized_flow := mean_value / sum(mean_value) * 100, by = type
]

# Step 7: Re-run validation
cat("\nRe-validating normalized flows...\n")
validation_check <- normalized_flows[
  , .(total_normalized_flow = sum(normalized_flow, na.rm = TRUE)), by = type
]

if (any(abs(validation_check$total_normalized_flow - 100) > 1e-6)) {
  cat("Error: Normalized flows still do not sum to 100% for some types. Please investigate further.\n")
  print(validation_check[abs(total_normalized_flow - 100) > 1e-6])
} else {
  cat("All normalized flows now sum to 100%.\n")
}

# Step 8: Save the cleaned and validated results
fwrite(normalized_flows, "data/c3/normalized_flows_crops_fixed.csv")
cat("Normalized flows saved to 'data/c3/normalized_flows_crops_fixed.csv'.\n")

# Validation: Ensure normalization sums to 100% for each type
validation_check <- normalized_flows[
  , .(total_normalized_flow = sum(normalized_flow, na.rm = TRUE)), by = type
]

# Check for any deviations from 100%
if (any(abs(validation_check$total_normalized_flow - 100) > 1e-6)) {
  stop("Error: Normalized flows do not sum to 100% for some types. Please recheck the data.")
} else {
  cat("Validation successful: All normalized flows sum to 100% for each type.\n")
}

# Normalize flows to calculate percentages
normalized_flows <- aggregated_results[
  , normalized_flow := if (sum(mean_value, na.rm = TRUE) == 0) 0 else (mean_value / sum(mean_value) * 100), by = type
]

# Validation: Ensure normalization sums to 100% for each type
validation_check <- normalized_flows[
  , .(total_normalized_flow = sum(normalized_flow, na.rm = TRUE)), by = type
]

# Save normalized flows to disk
fwrite(normalized_flows, "data/c3/normalized_flows_crops.csv")

# Output summary to console
cat("Normalization complete. Normalized flows saved to 'normalized_flows_crops.csv'.\n")
cat("\nValidation check (sum of normalized flows for each type should equal 100% or 0% if all values are zero):\n")
print(validation_check)

