
## Distribution of each item and flow----

# Load required libraries
library(data.table)
library(fitdistrplus)  # For fitting distributions
library(ggplot2)       # For visualization

# Simulated dataset
data <- dt %>% 
  dplyr::select(!c(Validation, dest_missing)) %>% # can't have negative values
  setDT()
# Load required libraries
library(data.table)
library(fitdistrplus)

# Simulated dataset (with attributes for demonstration)
set.seed(42)

# Remove all attributes from the dataset
remove_attributes <- function(df) {
  for (col in names(df)) {
    attributes(df[[col]]) <- NULL
  }
  return(df)
}

# Clean the data
data <- remove_attributes(data)

# Define the columns to which the function should be applied
flow_columns <- setdiff(names(data), c("y4_hhid", "item"))  # Exclude grouping columns
# Function to fit distributions and report the best fit
fit_distributions <- function(data_column) {
  # Ensure the column is numeric and has at least two valid values
  if (!is.numeric(data_column) || length(data_column) < 2 || length(unique(data_column)) < 2) {
    return(list(
      best_fit = NA,
      aic_values = NA,
      fit_objects = NA
    ))
  }
  
  # Fit candidate distributions
  fit_norm <- tryCatch(fitdist(data_column, "norm"), error = function(e) NULL)  # Normal distribution
  fit_lognorm <- if (all(data_column > 0)) {
    tryCatch(fitdist(data_column, "lnorm"), error = function(e) NULL)  # Log-normal distribution
  } else {
    NULL
  }
  fit_unif <- tryCatch(fitdist(data_column, "unif"), error = function(e) NULL)  # Uniform distribution
  
  # Remove NULL fits
  fits <- list(fit_norm, fit_lognorm, fit_unif)
  fits <- fits[!sapply(fits, is.null)]  # Filter out NULL fits
  
  # If no valid fits remain, return NA
  if (length(fits) == 0) {
    return(list(
      best_fit = NA,
      aic_values = NA,
      fit_objects = NA
    ))
  }
  
  # Compare goodness-of-fit statistics
  gof <- tryCatch(
    gofstat(fits),
    error = function(e) {
      message("Error during gofstat: ", e$message)
      return(NULL)
    }
  )
  
  # If gofstat fails, return NA
  if (is.null(gof)) {
    return(list(
      best_fit = NA,
      aic_values = NA,
      fit_objects = fits
    ))
  }
  
  # Return the best distribution based on AIC (smaller is better)
  best_fit <- names(which.min(gof$aic))
  list(
    best_fit = best_fit,
    aic_values = gof$aic,
    fit_objects = fits
  )
}

# Apply the function for each product-flow combination dynamically
results <- data[, lapply(.SD, function(col) {
  fit_distributions(col)  # Apply the fit_distributions function to each column
}), .SDcols = flow_columns, by = type]

# View results
print(results)

# Monte Carlo Simulation Script
# Required Libraries
library(data.table)  # For efficient processing
library(parallel)    # For parallel processing
library(networkD3)   # For Sankey diagram visualization

# Convert to data.table for faster processing
household_data <- as.data.table(dt)

# Monte Carlo Simulation Parameters
set.seed(123)
n_simulations <- 1000  # Number of simulations

# Function: Simulate uncertainty for each allocation
simulate_allocations <- function(mean, sd, n, type, household_id, destination) {
  # Validate inputs
  if (is.na(mean) || is.na(sd) || sd < 0) return(data.table())  # Return empty table for invalid cases
  if (sd == 0) {
    # Constant values if standard deviation is zero
    return(data.table(
      simulated_values = rep(mean, n),
      type = type,
      household_id = household_id,
      destination = destination
    ))
  }
  
  # Simulate values using normal distribution
  simulated_values <- rnorm(n, mean = mean, sd = sd)
  
  # Handle cases where negative values are not allowed
  simulated_values <- pmax(simulated_values, 0)
  
  # Return as a data.table
  return(data.table(
    simulated_values = simulated_values,
    type = type,
    household_id = household_id,
    destination = destination
  ))
}

# Function: Simulate for all destinations for a single household-food combination
simulate_household <- function(household_row, n_simulations) {
  household_id <- household_row$y4_hhid
  food_type <- household_row$type
  
  # Simulate for all destinations starting with "dest_"
  destination_cols <- grep("^dest_", names(household_row), value = TRUE)
  
  simulations <- lapply(destination_cols, function(destination) {
    mean <- household_row[[destination]]
    sd <- abs(mean) * 0.1  # Assume SD is 10% of the mean
    simulate_allocations(mean, sd, n_simulations, food_type, household_id, destination)
  })
  
  # Combine all destination simulations for the current household-food combination
  return(rbindlist(simulations, fill = TRUE))
}



# Save aggregated results to disk
fwrite(aggregated_results, "data/c3/aggregated_results_meat.csv")

## Validate aggregated results----
# Validation Script for Aggregated Results

# Load required libraries
library(data.table)

# Load aggregated results
aggregated_results <- fread("data/c3/aggregated_results_meat.csv")

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
if (anyDuplicated(aggregated_results[, .(type, destination)]) > 0) {
  cat("Error: Duplicate rows found for type and destination grouping.\n")
  print(aggregated_results[duplicated(aggregated_results[, .(type, destination)])])
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

# Normalize Flows -----
# Normalize flows to calculate percentages
normalized_flows <- aggregated_results[
  , normalized_flow := mean_value / sum(mean_value) * 100, by = type]

# Save normalized flows
fwrite(normalized_flows, "data/c3/normalized_flows_meat.csv")

# Load required libraries
library(data.table)

# Validate that `mean_value` has no missing or invalid data
if (any(is.na(aggregated_results$mean_value))) {
  stop("Error: `mean_value` contains missing (NA) values. Please fix the data before normalization.")
}

if (any(aggregated_results$mean_value < 0)) {
  stop("Error: `mean_value` contains negative values. Please fix the data before normalization.")
}

# Normalize flows to calculate percentages
normalized_flows <- aggregated_results[
  , normalized_flow := mean_value / sum(mean_value) * 100, by = type
]

# Validation: Ensure normalization sums to 100% for each type
validation_check <- normalized_flows[
  , .(total_normalized_flow = sum(normalized_flow, na.rm = TRUE)), by = type
]

if (any(abs(validation_check$total_normalized_flow - 100) > 1e-6)) {
  stop("Error: Normalized flows do not sum to 100% for some types. Please recheck the data.")
}

# Save normalized flows to disk
fwrite(normalized_flows, "data/c3/normalized_flows_meat.csv")

# Output summary to console
cat("Normalization complete. Normalized flows saved to 'normalized_flows_meat.csv'.\n")
print("Summary of normalized flows:")
print(normalized_flows[, .(type, destination, normalized_flow)])

cat("\nValidation check (sum of normalized flows for each type should equal 100%):\n")
print(validation_check)


## FOR Sankey-----
# Required Libraries
library(data.table)

# Load simulation results
simulation_results <- fread("data/c3/simulation_results_meat.csv")

# Summarize total flows by type and destination
sankey_data <- simulation_results[
  , .(total_flow = sum(simulated_values, na.rm = TRUE)),
  by = .(type, destination)
]

# Format data for Sankey diagram
# Assuming you have a `source` column in your data for the origin of the flow
sankey_format <- sankey_data[
  , .(source = type, target = destination, value = total_flow)
]

# Save the Sankey data to a CSV file for visualization
fwrite(sankey_format, "data/c3/sankey_data_meat.csv")

# Output summary to console
cat("Sankey data prepared successfully. Saved to 'data/c3/sankey_data_meat.csv'.\n")
print("Summary of Sankey data:")
print(sankey_format)