# --- Libraries ---
library(tidyverse)
library(data.table)
library(furrr)
library(parallel)

# --- Helper: Remove haven labels for all columns ---
clear.labels <- function(x) {
  if(is.list(x)) {
    for(i in seq_along(x)) {
      class(x[[i]]) <- setdiff(class(x[[i]]), 'labelled') 
      attr(x[[i]],"label") <- NULL
    } 
  } else {
    class(x) <- setdiff(class(x), "labelled")
    attr(x, "label") <- NULL
  }
  return(x)
}  

# --- Load data and select households for produced bootstrap ---
recall_details <- read_csv("2_data/results/recall_details.csv")
full_overview_hh4 <- read_csv("2_data/results/full_overview_hh4.csv")

# Completeness checks
expected_zones <- c("Central", "Coastal", "Lakes", "Northern Highlands", "Southern Highlands")
expected_months <- 1:12

actual_zones <- unique(full_overview_hh4$zone)
actual_months <- unique(full_overview_hh4$month)
missing_zones <- setdiff(expected_zones, actual_zones)
missing_months <- setdiff(expected_months, actual_months)
if (length(missing_zones) > 0 | length(missing_months) > 0) {
  stop(paste(
    "Missing zones:", paste(missing_zones, collapse = ","),
    "Missing months:", paste(missing_months, collapse = ",")
  ))
}

zone_month_grid <- expand.grid(zone = expected_zones, month = expected_months)
present_zone_months <- full_overview_hh4 %>% select(zone, month) %>% unique()
missing_zone_months <- anti_join(zone_month_grid, present_zone_months, by = c("zone", "month"))
if (nrow(missing_zone_months) > 0) {
  message("Missing zone-month combinations: ", paste(apply(missing_zone_months, 1, paste, collapse = "-"), collapse = "; "))
}

incl_3b <- full_overview_hh4 %>% 
  filter(hh_type == "agricultural" & is.na(final_status4)) %>% 
  select(y4_hhid, zone, month) %>% 
  distinct()

recall_3b <- recall_details %>% 
  inner_join(select(incl_3b, y4_hhid), by = "y4_hhid") %>% 
  select(y4_hhid, zone, month, shortnames, quant_afe_mo, purch_afe_mo, produced_afe_mo, gifts_afe_mo) %>% 
  clear.labels() %>% 
  dplyr::rename(
    quant = quant_afe_mo,
    purch = purch_afe_mo,
    produced = produced_afe_mo,
    gifts = gifts_afe_mo
  )

saveRDS(recall_3b, "2_data/final/recall_3b.RDS", compress = TRUE)

# --- Household counts per zone ---
n_hh_zone_allmonths <- recall_3b %>% 
  distinct(y4_hhid, zone) %>% 
  group_by(zone) %>% 
  summarise(n = n(), .groups="drop") %>% 
  setDT()

# --- Overview of missing zone-months ---
miss_mo <- recall_3b %>% 
  distinct(zone, month, y4_hhid) %>% 
  group_by(zone, month) %>% 
  summarise(n = n(), .groups="drop") %>% 
  pivot_wider(names_from = zone, values_from = n) %>% 
  mutate(across(-month, ~replace_na(.,0))) %>% 
  arrange(month)

# --- Reformat to wide: produced only ---
boot_in <- copy(recall_3b)

miss_prod <- boot_in %>% 
  arrange(shortnames) %>% 
  select(y4_hhid, zone, month, shortnames, var = produced) %>% 
  pivot_wider(names_from = shortnames, values_from = var) %>% 
  setDT() %>% 
  mutate(across(where(is.numeric), ~replace_na(.x, 0)))

# NA check after pivot
if (any(is.na(miss_prod$zone)) | any(is.na(miss_prod$y4_hhid))) {
  stop("NA values found in household or zone after pivot_wider. Check source data for missing values before pivot.")
}

# --- Impute missing/low-n zone-months from within the same zone (prev/same/next month only, not from other zones) ---
get_month_window <- function(month, all_months) {
  prev_month <- if (month > min(all_months)) month - 1 else NA
  next_month <- if (month < max(all_months)) month + 1 else NA
  unique(na.omit(c(prev_month, month, next_month)))
}

impute_within_zone <- function(df, n = 10) {
  all_months <- sort(unique(df$month))
  zones <- unique(df$zone)
  value_cols <- setdiff(names(df), c("y4_hhid", "zone", "month"))
  zone_month_counts <- df %>%
    group_by(zone, month) %>%
    tally(name = "count") %>%
    ungroup()
  all_combos <- expand.grid(zone = zones, month = all_months)
  need_impute <- all_combos %>%
    left_join(zone_month_counts, by = c("zone", "month")) %>%
    mutate(count = ifelse(is.na(count), 0, count),
           missing_n = n - count) %>%
    filter(missing_n > 0)
  imputed_rows <- purrr::pmap_dfr(need_impute, function(zone, month, count, missing_n) {
    months_window <- get_month_window(month, all_months)
    pool <- df %>% filter(zone == !!zone, month %in% months_window)
    if (nrow(pool) == 0) return(NULL)
    slice_sample(pool, n = missing_n, replace = TRUE) %>%
      mutate(month = month, y4_hhid = "99-99", zone = zone)
  })
  all_filled <- bind_rows(df, imputed_rows)
  zone_month_counts2 <- all_filled %>%
    group_by(zone, month) %>%
    tally(name = "count") %>%
    ungroup()
  still_missing <- all_combos %>%
    left_join(zone_month_counts2, by = c("zone", "month")) %>%
    mutate(count = ifelse(is.na(count), 0, count),
           missing_n = n - count) %>%
    filter(missing_n > 0)
  if (nrow(still_missing) > 0) {
    synthetic_rows <- purrr::pmap_dfr(still_missing, function(zone, month, count, missing_n) {
      syn <- data.frame(
        y4_hhid = paste0("95-95_", seq_len(missing_n)),
        zone = zone,
        month = month,
        stringsAsFactors = FALSE
      )
      for (col in value_cols) syn[[col]] <- 0
      syn
    })
    all_filled <- bind_rows(all_filled, synthetic_rows)
  }
  all_filled <- as.data.table(all_filled)
  all_filled[, (value_cols) := lapply(.SD, function(x) replace_na(x, 0)), .SDcols = value_cols]
  return(all_filled[])
}

set.seed(1234)
prod <- impute_within_zone(miss_prod, n = 10)

# --- Final NA check after imputation ---
if (any(is.na(prod))) {
  warning("NAs found in prod after imputation. These will be replaced with 0.")
  prod[is.na(prod)] <- 0
}

# --- Bootstrap function for each zone, memory optimized, returns long dt with sd ---
def_n <- function(zone_name) {
  n_hh_zone %>% filter(zone == zone_name) %>% pull(n)
}

bootstrap_means <- function(data, n_samples, n_reps, food_items) {
  result_list <- vector("list", n_reps)
  for (i in seq_len(n_reps)) {
    sampled_data <- data[, lapply(.SD, sample, size = n_samples, replace = TRUE), by = month, .SDcols = food_items][,
                                                                                                                    ID := rep(1:n_samples, times = uniqueN(month))]
    long_data <- melt(sampled_data,
                      id.vars = c("ID", "month"),
                      measure.vars = food_items,
                      variable.name = "item",
                      value.name = "value")
    long_data[, value := as.numeric(value)]
    result_list[[i]] <- long_data[, .(value = mean(value, na.rm = TRUE)), by = .(ID, item, month)][, rep := i]
    rm(sampled_data, long_data); if(i %% 10 == 0) gc()
  }
  combined <- rbindlist(result_list)
  summary_data <- combined[, .(
    value = mean(value, na.rm = TRUE),
    sd = sd(value, na.rm = TRUE)
  ), by = .(ID, item, month)]
  setcolorder(summary_data, c("ID", "item", "month", "value", "sd"))
  return(summary_data[])
}

# --- Running the bootstrap for each zone, saving each zone to disk ---
# Fix def_n function

# set.seed(26587)
n_reps <- 1000
food_items <- colnames(prod)[!(colnames(prod) %in% c("y4_hhid", "zone", "month"))]
boot_dir <- "2_data/results/boot_zone_chunks"
dir.create(boot_dir, recursive = TRUE, showWarnings = FALSE)
zone_names <- unique(prod$zone)
# 
# for(zone_name in zone_names) {
#   cat("Bootstrapping zone:", zone_name, "\n")
#   data <- prod[zone == zone_name]
#   data[, (food_items) := lapply(.SD, as.numeric), .SDcols = food_items]
#   n_samples <- def_n(zone_name)
#   final_data <- bootstrap_means(data, n_samples, n_reps, food_items)
#   final_data[, zone := zone_name]
#   saveRDS(final_data, file.path(boot_dir, paste0("boot_", gsub(" ", "_", zone_name), ".RDS")))
#   rm(final_data); gc()
# }
# # Combine all zones at end
# boot_results <- lapply(zone_names, function(z) readRDS(file.path(boot_dir, paste0("boot_", gsub(" ", "_", z), ".RDS"))))
# boot_results_long <- rbindlist(boot_results)
# saveRDS(boot_results_long, "2_data/results/boot_results_long.RDS")

# Checks before boot

# Identify the food item columns
food_items <- colnames(prod)[which(colnames(prod) == "alocohol"):which(colnames(prod) == "yams")]

# Pivot to long format
prod_long <- prod %>%
  pivot_longer(
    cols = all_of(food_items),
    names_to = "item",
    values_to = "value"
  ) %>% 
  left_join(hh_grps, by = c("item" = "shortnames")) %>%
  group_by(zone, month, group) %>% 
  summarise(mean = mean(value))


# --- Additional Bootstrap: Column-wise (Mosaic) Sampling ---
# For each zone and month, generate synthetic households by sampling each column independently
def_n <- function(zone_name) {
  n_hh_zone_allmonths %>% filter(zone == zone_name) %>% pull(n)
}
n_reps <- 1000
set.seed(9876)
mosaic_boot_dir <- "2_data/results/mosaic_boot_zone_chunks"
dir.create(mosaic_boot_dir, recursive = TRUE, showWarnings = FALSE)

mosaic_bootstrap_zone_month <- function(data, n_hh, n_reps, food_items) {
  print("Columns in data at function entry:")
  print(names(data))
  # data: data.table for one zone and month only
  # n_hh: number of synthetic households to generate per rep
  # n_reps: number of bootstrap replications
  # food_items: columns to sample independently
  boot_list <- vector("list", n_reps)
  for (rep in seq_len(n_reps)) {
    # For each synthetic household, sample each food item independently from all rows
    synth_hhs <- replicate(
      n_hh,
      {
        vals <- sapply(food_items, function(col) sample(data[[col]], 1, replace = TRUE))
        as.list(vals)
      },
      simplify = FALSE
    )
    synth_dt <- rbindlist(lapply(seq_along(synth_hhs), function(i) {
      as.data.table(synth_hhs[[i]])[, ID := i]
    }))
    synth_dt[, rep := rep]
    boot_list[[rep]] <- synth_dt
    if(rep %% 10 == 0) gc()
  }
  boot_total <- rbindlist(boot_list)
  # Calculate mean and sd per food item, per rep
  boot_summary <- boot_total[, lapply(.SD, mean, na.rm = TRUE), by = .(rep, ID), .SDcols = food_items]
  boot_summary <- melt(boot_summary, id.vars = c("rep", "ID"), variable.name = "item", value.name = "value")
  boot_summary
}

zone_names <- unique(prod$zone)

for (zone_name in zone_names) {
  cat("Mosaic-bootstrapping zone:", zone_name, "\n")
  zone_data <- prod[zone == zone_name]
  n_hh <- n_hh_zone_allmonths[zone == zone_name, n]
  
  mosaic_zone_results <- list()
  for (mo in unique(zone_data$month)) {
    mo_data <- zone_data[month == mo]
    if(n_hh == 0) next
    mosaic_rep <- mosaic_bootstrap_zone_month(mo_data, n_hh, n_reps, food_items)
    mosaic_rep[, `:=`(zone = zone_name, month = mo)]
    mosaic_zone_results[[as.character(mo)]] <- mosaic_rep
  }
  if (length(mosaic_zone_results) == 0) {
    # Always write an empty data.table with the correct columns
    empty_dt <- data.table(rep=integer(), ID=integer(), item=character(), value=numeric(), zone=character(), month=integer())
    saveRDS(empty_dt, file.path(mosaic_boot_dir, paste0("mosaic_boot_", gsub(" ", "_", zone_name), ".RDS")))
  } else {
    mosaic_zone_dt <- rbindlist(mosaic_zone_results)
    saveRDS(mosaic_zone_dt, file.path(mosaic_boot_dir, paste0("mosaic_boot_", gsub(" ", "_", zone_name), ".RDS")))
    rm(mosaic_zone_dt); gc()
  }
}
# Combine all zones
mosaic_boot_results <- lapply(zone_names, function(z) readRDS(file.path(mosaic_boot_dir, paste0("mosaic_boot_", gsub(" ", "_", z), ".RDS"))))
mosaic_boot_results_long <- rbindlist(mosaic_boot_results)

etDT(mosaic_boot_results_long)

# Aggregate to get mean and sd for each zone, ID, month, and item
agg <- mosaic_boot_results_long[
  , .(
    mean = mean(value, na.rm = TRUE),
    sd   = sd(value, na.rm = TRUE)
  ),
  by = .(zone, ID, month, item)
]

saveRDS(agg, "2_data/results/mosaic_boot_results_long.RDS")

