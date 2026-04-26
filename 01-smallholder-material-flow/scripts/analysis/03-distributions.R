# Distributions

## Distribution of crop item and flow----
# Load required libraries
library(fitdistrplus)  # For fitting distributions
# Simulated dataset
data <- dt %>% 
  #  dplyr::select(!c(item, Validation)) %>% # can't have negative values
  mutate(item = as.character(type),
         dest_error = ifelse(dest_missing<0, dest_missing, 0),
         dest_missing = ifelse(dest_missing<=0, dest_missing, 0)) %>% 
  dplyr::select(!type, Validation) %>% 
  setDT()

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
}), .SDcols = flow_columns, by = item]

# View results
print(results)



