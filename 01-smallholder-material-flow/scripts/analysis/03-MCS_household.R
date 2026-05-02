# Monte Carlo simulation----
## Load packages----
library(parallel)    # For parallel processing
library(networkD3)   # For Sankey diagram visualization

# Functions----
# Monte Carlo Simulation Parameters
set.seed(123)
n_simulations <- 1000  # Number of simulations

# Function: Simulate uncertainty for each allocation
simulate_allocations <- function(mean, sd, n, type, household_id, destination, allow_negatives = TRUE) {
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
  if (!allow_negatives) {
    simulated_values <- pmax(simulated_values, 0)
  }
  
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

aggregate_simulation_results <- function(simulation_results) {
  library(data.table)
  
  # Ensure the input is a data.table
  if (!"data.table" %in% class(simulation_results)) {
    stop("Input must be a data.table.")
  }
  
  # Check required columns
  required_columns <- c("household_id", "type", "destination", "simulated_values")
  missing_columns <- setdiff(required_columns, names(simulation_results))
  if (length(missing_columns) > 0) {
    stop("The following required columns are missing: ", paste(missing_columns, collapse = ", "))
  }
  
  # Perform aggregation
  aggregated_results <- simulation_results[
    , .(
      mean_value = mean(simulated_values, na.rm = TRUE),  # Mean across simulations
      sd_value = sd(simulated_values, na.rm = TRUE),      # Standard deviation
      count = .N                                          # Number of simulations
    ),
    by = .(household_id, type, destination)              # Grouping columns
  ]
  
  return(aggregated_results)
}

# validation function
validate_aggregated_data <- function(aggregated_results, output_file = "validation_report.rds") {
  library(data.table)
  
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
  str(aggregated_results)
  if (!all(sapply(aggregated_results[, .(mean_value, sd_value, count)], is.numeric))) {
    stop("Error: Non-numeric values found in numeric columns.")
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
    stop("Error: Negative standard deviation values found.")
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
    stop("Error: Duplicate rows found for type and destination grouping.")
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
  
  # 8. Negative Values
  cat("\nChecking for negative mean values...\n")
  if (any(aggregated_results$mean_value < 0)) {
    stop("Error: Negative mean values found.")
  } else {
    cat("No negative mean values found.\n")
  }
  
  # # 9. Verify Normalization
  # cat("\nValidating normalization of mean values...\n")
  # validation_check <- aggregated_results[
  #   , .(total_mean = sum(mean_value, na.rm = TRUE)), by = .(type, destination)
  # ]
  # if (any(abs(validation_check$total_mean - 100) > 1e-6)) {
  #   stop("Error: Normalized mean values do not sum to 100% for some type-destination groups.")
  # } else {
  #   cat("All type-destination groups are properly normalized.\n")
  # }
  
  # 10. Outliers
  cat("\nChecking for outliers in mean and standard deviation...\n")
  mean_threshold <- mean(aggregated_results$mean_value, na.rm = TRUE) + 3 * sd(aggregated_results$mean_value, na.rm = TRUE)
  sd_threshold <- mean(aggregated_results$sd_value, na.rm = TRUE) + 3 * sd(aggregated_results$sd_value, na.rm = TRUE)
  
  outliers <- aggregated_results[
    mean_value > mean_threshold | sd_value > sd_threshold
  ]
  if (nrow(outliers) > 0) {
    cat("Warning: Outliers detected in the data.\n")
    print(outliers)
  } else {
    cat("No outliers detected.\n")
  }
  
  # 11. Missing Destinations
  cat("\nChecking for missing type-destination combinations...\n")
  all_combinations <- CJ(
    type = unique(aggregated_results$type),
    destination = unique(aggregated_results$destination)
  )
  
  missing_combinations <- all_combinations[
    !aggregated_results, on = .(type, destination)
  ]
  
  if (nrow(missing_combinations) > 0) {
    cat("Warning: Missing type-destination combinations found.\n")
    print(missing_combinations)
  } else {
    cat("No missing type-destination combinations.\n")
  }
  
  # 12. Save Validation Report
  cat("\nSaving validation report...\n")
  validation_report <- list(
    missing_values = missing_values,
    summary_stats = summary_stats
  )
  saveRDS(validation_report, output_file)
  cat("Validation report saved as", output_file, "\n")
}

# Simularion script----

## Crops----
crops <- readRDS(here::here("data", "processed", "01", "mfa_crops.RDS")) 
excl_3a <- read_csv(here::here("data", "processed", "01", "excl_3a.csv"))

### Checks and changes to data----
dt <- crops %>% 
  anti_join(excl_3a, by = "y4_hhid") %>%  # remove excluded households
  rowwise() %>% 
  mutate(
    stored = stored-seed, # stored for seed as defined in survey
    stored = ifelse(stored<0, seed, stored), # assume seed is part of stored
    processing = ifelse(newprocessing < 0, 0, newprocessing)) %>%  # contains processing not already included in sales and consumption, keep negative
    #valiproc = processing <= sold+consumed,
    #consumednew = ifelse(valiproc == T & consumed < inprodcons, consumed-inprodcons, consumed),
    #soldnew = ifelse(valiproc == T & sold < inprodsold, sold-inprodsold, sold))
    # consumed = consumed-inprodcons, # assume processing in consumption, hence remove 
    # sold = sold-inprodsold,
    # consumed = ifelse(consumed<0, 0, consumed), # assume processing separate from consumed for at least some households
    # sold = ifelse(sold<0, 0, sold)
    
    # valproc = processing == prodproduced+waste,
    # valdest = prodproduced == prodsold+prodconsumed,
  dplyr::select(y4_hhid:feed,processing) %>% # residue not part of production volume
  group_by(y4_hhid, type) %>% 
  summarise(across(where(is.numeric), ~sum(.x, na.rm = TRUE))) %>% 
  rowwise() %>%
  mutate(
    missing = produced - abs(sold+stored+losses+consumed+payment+gifts+feed+processing),
    Validation = abs(sold+stored+losses+consumed+payment+gifts+feed+processing) - produced < 1e-8
  ) %>%
  ungroup()

colnames(dt)[4:13] <- paste0("dest_", colnames(dt)[4:13]) # add destination for better use of function

# assume processing in sold/consumed when it fits, when it doesn't its assumed separate
# processing and destinations later to be allocated proportionately from the reconciled processing value
fwrite(dt, here::here("data", "processed", "01", "mfa_crops_cleaned.csv"))

### Simulation----
# Convert to data.table for faster processing
household_data <- dt %>% 
  setDT() 

# Parallel Simulation for All Household-Food Combinations
num_cores <- detectCores() - 1  # Use all but one core
cl <- makeCluster(num_cores)

# Load required libraries on all workers
clusterEvalQ(cl, {
  library(data.table)  # Ensure data.table is loaded on all workers
})

# Export necessary variables and functions to the cluster
clusterExport(cl, c("household_data", "simulate_household", "simulate_allocations", "n_simulations"))

# Run simulations in parallel
simulation_results <- rbindlist(parLapply(cl, 1:nrow(household_data), function(i) {
  simulate_household(household_data[i], n_simulations)
}), fill = TRUE)

# Stop the cluster
stopCluster(cl)

# Save simulation results to disk (to avoid re-running on large datasets)
fwrite(simulation_results, here::here("data", "processed", "01", "simulation_results_crops_negative.csv"))

### Adjust negative----
# NOTE (backlog): adjustment distributes the negative balance equally across
# non-missing flows by row count. A stricter implementation would distribute
# proportionally by flow magnitude. Consistent with R version — revisit if
# uncertainty estimates are used for policy-sensitive comparisons.
# Identify households with negative dest_missing
negative_households <- simulation_results[destination == "dest_missing" & simulated_values < 0]

fwrite(negative_households, "data/c3/negative_crops.csv")

# Proportionally adjust other flows based on negative dest_missing
simulation_results[
  household_id %in% negative_households$household_id & destination != "dest_missing",
  flows_adjusted := simulated_values + (sum(destination == "dest_missing") / sum(destination != "dest_missing"))
]

# Reset dest_missing to 0 for affected households
simulation_results[
  household_id %in% negative_households$household_id & destination == "dest_missing",
  simulated_values := 0
]

# Save simulation results to disk (to avoid re-running on large datasets)
fwrite(simulation_results, "data/c3/simulation_results_crops.csv")

### Aggregation to household----
aggregated_results <- aggregate_simulation_results(simulation_results)

fwrite(aggregated_results, "data/c3/aggregated_results_crops.csv")

### Validation----
# Validation Script for Aggregated Results
val_crops <- validate_aggregated_data(aggregated_results)

## Animal products----
eggs <- readRDS(here::here("data", "processed", "01", "mfa_eggs.RDS")) 
milk <- readRDS(here::here("data", "processed", "01", "mfa_milk.RDS")) 

### Checks and changes to data----
eggs <- eggs %>% 
  dplyr::select(!feed:grazed) %>% 
  anti_join(excl_3a, by = "y4_hhid") %>%  # remove excluded households
  dplyr::select(y4_hhid:consumed) %>%  # redo, and ignore processing
  rename(type = item) %>% 
  rowwise() %>% 
  mutate(
    processing = 0,
    missing = produced-sum(c_across(sold:consumed)),
    # Check if the sum of all allocations is equal to 1
    Validation = abs(sum(c_across(c(sold, consumed, processing, missing))) - produced) < 1e-8)

milk <- milk %>% 
  #dplyr::select(-feed, -grazed) %>% 
  anti_join(excl_3a, by = "y4_hhid") %>%  # remove excluded households
  mutate(
    type = paste0("milk - ", type),
    produced = produced - psold
  ) %>%
  dplyr::select(y4_hhid, type, produced, sold, consumed, processing = processed) %>%  
  rowwise() %>% 
  mutate(
    missing = produced - sum(c_across(c(sold, consumed, processing))),
    Validation = abs(sum(c_across(c(sold, consumed, processing, missing))) - produced) < 1e-8
  ) %>%
  ungroup()


# check below.
dt <- bind_rows(eggs, milk) 

colnames(dt)[4:7] <- paste0("dest_", colnames(dt)[4:7]) # add destination for better use of function
fwrite(dt, "data/c3/mfa_ap_cleaned.csv")

household_data <- as.data.table(dt)

### Simulation----
# Parallel Simulation for All Household-Food Combinations
num_cores <- detectCores() - 1  # Use all but one core
cl <- makeCluster(num_cores)

# Load required libraries on all workers
clusterEvalQ(cl, {
  library(data.table)  # Ensure data.table is loaded on all workers
})

# Export necessary variables and functions to the cluster
clusterExport(cl, c("household_data", "simulate_household", "simulate_allocations", "n_simulations"))

# Run simulations in parallel
simulation_results <- rbindlist(parLapply(cl, 1:nrow(household_data), function(i) {
  simulate_household(household_data[i], n_simulations)
}), fill = TRUE)

# Stop the cluster
stopCluster(cl)

### Adjust negative----
# Identify households with negative dest_missing
negative_households <- simulation_results[destination == "dest_missing" & simulated_values < 0]

fwrite(negative_households, "data/c3/negative_ap.csv")

# Proportionally adjust other flows based on negative dest_missing
simulation_results[
  household_id %in% negative_households$household_id & destination != "dest_missing",
  flows_adjusted := simulated_values + (sum(destination == "dest_missing") / sum(destination != "dest_missing"))
]

# Reset dest_missing to 0 for affected households
simulation_results[
  household_id %in% negative_households$household_id & destination == "dest_missing",
  simulated_values := 0
]

# Save simulation results to disk (to avoid re-running on large datasets)
fwrite(simulation_results, "data/c3/simulation_results_ap.csv")

### Aggregate----
aggregated_results <- aggregate_simulation_results(simulation_results)
fwrite(aggregated_results, "data/c3/aggregated_results_ap.csv")

### Validation----
val_ap <- validate_aggregated_data(aggregated_results)

## Slaughter product----
# Slaughter products
meat <- readRDS(here::here("data", "processed", "01", "mfa_animals.RDS"))
# Replace NA with 0 in all numeric columns only
num_cols <- names(meat)[sapply(meat, is.numeric)]
meat[, (num_cols) := lapply(.SD, function(x) fifelse(is.na(x), 0, x)), .SDcols = num_cols]

dt <- meat %>% 
  dplyr::select(!need:grazed) %>% 
  filter(slaughter>0) %>% # reduces the number of outliers
  anti_join(excl_3a, by = "y4_hhid") %>%  # remove excluded households
  mutate(type = paste0("slaughter - ", type),
         match = total_weight == (cons_weight + sold_weight)) %>%
  dplyr::select(y4_hhid, type, produced = total_weight, sold = sold_weight, meat, offal, hides, inedible) %>% 
  group_by(y4_hhid, type) %>% 
  summarise(across(where(is.numeric), ~sum(.x, na.rm = TRUE))) %>% 
  ungroup() %>% 
  rowwise() %>% 
  mutate(
    missing = produced-(sold+meat+offal+hides+inedible),
    # Check if the sum of all allocations is equal to 1
    Validation = (sold+meat+offal+hides+inedible+missing) == produced) 

colnames(dt)[4:9] <- paste0("dest_", colnames(dt)[4:9]) # add destination for better use of function

fwrite(dt, "data/c3/mfa_meat_cleaned.csv")

### Simulation----

household_data <- as.data.table(dt)

# Parallel Simulation for All Household-Food Combinations
num_cores <- detectCores() - 1  # Use all but one core
cl <- makeCluster(num_cores)

# Load required libraries on all workers
clusterEvalQ(cl, {
  library(data.table)  # Ensure data.table is loaded on all workers
})

# Export necessary variables and functions to the cluster
clusterExport(cl, c("household_data", "simulate_household", "simulate_allocations", "n_simulations"))

# Run simulations in parallel
simulation_results <- rbindlist(parLapply(cl, 1:nrow(household_data), function(i) {
  simulate_household(household_data[i], n_simulations)
}), fill = TRUE)

# Stop the cluster
stopCluster(cl)

### Adjust negative----
# Identify households with negative dest_missing
negative_households <- simulation_results[destination == "dest_missing" & simulated_values < 0]

fwrite(negative_households, "data/c3/negative_meat.csv")

# Proportionally adjust other flows based on negative dest_missing
simulation_results[
  household_id %in% negative_households$household_id & destination != "dest_missing",
  flows_adjusted := simulated_values + (sum(destination == "dest_missing") / sum(destination != "dest_missing"))
]

# Reset dest_missing to 0 for affected households
simulation_results[
  household_id %in% negative_households$household_id & destination == "dest_missing",
  simulated_values := 0
]

# Save simulation results to disk (to avoid re-running on large datasets)
fwrite(simulation_results, "data/c3/simulation_results_meat.csv")

### Aggregate----
aggregated_results <- aggregate_simulation_results(simulation_results)
fwrite(aggregated_results, "data/c3/aggregated_results_meat.csv")

# Compare the outliers with other groups
summary_stats <- aggregated_results[
  type == "slaughter - small ruminants",
  .(mean_mean_value = mean(mean_value, na.rm = TRUE),
    mean_sd_value = mean(sd_value, na.rm = TRUE))
]
print(summary_stats)

# Visualize distributions
ggplot(aggregated_results, aes(x = type, y = mean_value)) +
  geom_boxplot() +
  labs(title = "Boxplot of Mean Values by Type")

### Validation----
val_meat <- validate_aggregated_data(aggregated_results)
