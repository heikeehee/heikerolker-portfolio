# ---- 0. Workflow Outline ----
# ... [Outline kept as comments for documentation] ...

# ---- 1. Load libraries ----
library(data.table)
library(tidyverse)
library(readxl)
library(gt)
library(naniar)
library(furrr)
library(purrr)

# ---- 2. Helper functions ----
sum_na <- function(x) sum(x, na.rm=TRUE)
mean_na <- function(x) mean(x, na.rm=TRUE)
round_df <- function(df) df %>% mutate(across(where(is.numeric), round, 1))

clear_labels <- function(x) {
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

# ---- 3. Load and clean data ----
aFMe_summaries <- read_csv("2_data/final/aFMe_summaries.csv")
full_overview_hh4 <- fread("2_data/results/full_overview_hh4.csv")
LSMS_items_match <- readRDS("2_data/final/LSMS_items_match_fin.RDS")

# Clean household groups and join with shortnames
hh_grps <- LSMS_items_match %>%
  select(itemcode, group) %>%
  unique() %>%
  filter(!is.na(itemcode), group != "slaughter") %>%
  arrange(itemcode)

shortnames <- read_excel("2_data/reference/shortnames.xlsx") %>%
  mutate(itemcode = str_to_sentence(itemcode))

hh_grps <- hh_grps %>% left_join(shortnames, by = "itemcode")
hh_grps <- hh_grps %>%
  distinct(itemcode, .keep_all = TRUE)

# Define included hosueholds
incl_recall <- full_overview_hh4 %>%
  filter(status_recall == "included") %>%
  select(y4_hhid) %>% 
  distinct()

# Prepare main recall data
recall_3b_appendix <- fread("2_data/results/recall_details.csv") %>%
  as_tibble() %>%
  mutate(itemcode = str_to_sentence(itemcode)) %>%
  left_join(select(hh_grps, group, itemcode), by = "itemcode")

# Ensure relevant columns are numeric
recall_3b_appendix <- recall_3b_appendix %>%
  mutate(across(
    c(quant_afe_mo, purch_afe_mo, produced_afe_mo, gifts_afe_mo, quant, purch, produced, gifts),
    ~ suppressWarnings(as.numeric(.))
  )) %>% 
  inner_join(incl_recall) # only keep included households

# ---- 4. Completeness checks ----
expected_zones <- c("Central", "Coastal", "Lakes", "Northern Highlands", "Southern Highlands")
expected_months <- 1:12

actual_zones <- unique(recall_3b_appendix$zone)
actual_months <- unique(recall_3b_appendix$month)
missing_zones <- setdiff(expected_zones, actual_zones)
missing_months <- setdiff(expected_months, actual_months)

if (length(missing_zones) > 0 | length(missing_months) > 0) {
  stop(paste(
    "Missing zones:", paste(missing_zones, collapse = ","),
    "Missing months:", paste(missing_months, collapse = ",")
  ))
}
zone_month_grid <- expand.grid(zone = expected_zones, month = expected_months)
present_zone_months <- recall_3b_appendix %>% select(zone, month) %>% unique()
missing_zone_months <- anti_join(zone_month_grid, present_zone_months, by = c("zone", "month"))
if (nrow(missing_zone_months) > 0) {
  message("Missing zone-month combinations: ", paste(apply(missing_zone_months, 1, paste, collapse = "-"), collapse = "; "))
}

# ---- 5. Summarize/statistics functions ----
summarise_consumption <- function(df) {
  df %>%
    group_by(zone, month, y4_hhid, group) %>%
    summarise(
      count = sum(quant_afe_mo > 0, na.rm = TRUE),
      sm.quant = sum_na(quant_afe_mo),
      .groups = "drop"
    )
}

# ---- 6. Wide-format data creation ----
boot_ap <- recall_3b_appendix %>%
  mutate(y4_hhid = as.character(y4_hhid), zone = as.character(zone)) %>%
  pivot_wider(
    id_cols = c(y4_hhid, zone, month),
    names_from = shortnames,
    values_from = quant_afe_mo
  )
value_cols <- setdiff(names(boot_ap), c("y4_hhid", "zone", "month"))
boot_ap <- boot_ap %>%
  mutate(across(all_of(value_cols), ~ suppressWarnings(as.numeric(.))))

if (any(is.na(boot_ap$zone)) | any(is.na(boot_ap$y4_hhid))) {
  stop("NA values found in household or zone after pivot_wider. Check source data for missing values before pivot.")
}

# ---- 7. Imputation/sampling functions ----
get_month_window <- function(month, all_months) {
  prev_month <- if (month > min(all_months)) month - 1 else NA
  next_month <- if (month < max(all_months)) month + 1 else NA
  unique(na.omit(c(prev_month, month, next_month)))
}

impute_within_zone <- function(data, n = 10) {
  all_months <- sort(unique(data$month))
  zones <- unique(data$zone)
  value_cols <- setdiff(names(data), c("zone", "month", "y4_hhid"))
  all_combos <- expand.grid(zone = zones, month = all_months, stringsAsFactors = FALSE)
  
  # Initial counts
  zone_month_counts <- data %>%
    group_by(zone, month) %>%
    tally(name = "count") %>%
    ungroup()
  
  need_impute <- all_combos %>%
    left_join(zone_month_counts, by = c("zone", "month")) %>%
    mutate(count = ifelse(is.na(count), 0, count),
           missing_n = n - count) %>%
    filter(missing_n > 0)
  
  imputed_rows <- purrr::pmap_dfr(need_impute, function(zone, month, count, missing_n) {
    months_window <- get_month_window(month, all_months)
    pool <- data %>% filter(zone == !!zone, month %in% months_window)
    if (nrow(pool) == 0) return(NULL)
    slice_sample(pool, n = missing_n, replace = TRUE) %>%
      mutate(month = month, y4_hhid = "99-99")
  })
  
  full_data <- bind_rows(data, imputed_rows)
  
  # Check for any still-missing zone-months
  zone_month_counts2 <- full_data %>%
    group_by(zone, month) %>%
    tally(name = "count") %>%
    ungroup()
  still_missing <- all_combos %>%
    left_join(zone_month_counts2, by = c("zone", "month")) %>%
    mutate(count = ifelse(is.na(count), 0, count),
           missing_n = n - count) %>%
    filter(missing_n > 0)
  
  # Try zone-wide (all months) pool
  if (nrow(still_missing) > 0) {
    imputed_rows2 <- purrr::pmap_dfr(still_missing, function(zone, month, count, missing_n) {
      pool <- data %>% filter(zone == !!zone)
      if (nrow(pool) == 0) return(NULL)
      slice_sample(pool, n = missing_n, replace = TRUE) %>%
        mutate(month = month, y4_hhid = "98-98")
    })
    full_data <- bind_rows(full_data, imputed_rows2)
    imputed_rows <- bind_rows(imputed_rows, imputed_rows2)
    # Recheck
    zone_month_counts3 <- full_data %>%
      group_by(zone, month) %>%
      tally(name = "count") %>%
      ungroup()
    still_missing2 <- all_combos %>%
      left_join(zone_month_counts3, by = c("zone", "month")) %>%
      mutate(count = ifelse(is.na(count), 0, count),
             missing_n = n - count) %>%
      filter(missing_n > 0)
    # If any still missing, fill with synthetic (all zeros)
    if (nrow(still_missing2) > 0) {
      synthetic_rows <- purrr::pmap_dfr(still_missing2, function(zone, month, count, missing_n) {
        syn <- data.frame(
          y4_hhid = paste0("95-95_", seq_len(missing_n)),
          zone = zone,
          month = month,
          stringsAsFactors = FALSE
        )
        for (col in value_cols) syn[[col]] <- 0
        syn
      })
      full_data <- bind_rows(full_data, synthetic_rows)
      imputed_rows <- bind_rows(imputed_rows, synthetic_rows)
    }
  }
  # Final NA check: replace any accidental NA with 0
  full_data <- full_data %>% mutate(across(all_of(value_cols), ~replace_na(., 0)))
  list(
    imputed_data = full_data,
    imputed_only = imputed_rows
  )
}

impute_across_zones <- function(data, n = 10) {
  all_months <- sort(unique(data$month))
  zones <- unique(data$zone)
  value_cols <- setdiff(names(data), c("zone", "month", "y4_hhid"))
  all_combos <- expand.grid(zone = zones, month = all_months, stringsAsFactors = FALSE)
  
  # Initial counts
  zone_month_counts <- data %>%
    group_by(zone, month) %>%
    tally(name = "count") %>%
    ungroup()
  
  need_impute <- all_combos %>%
    left_join(zone_month_counts, by = c("zone", "month")) %>%
    mutate(count = ifelse(is.na(count), 0, count),
           missing_n = n - count) %>%
    filter(missing_n > 0)
  
  imputed_rows <- purrr::pmap_dfr(need_impute, function(zone, month, count, missing_n) {
    pool <- data %>% filter(month == !!month)
    if (nrow(pool) == 0) return(NULL)
    slice_sample(pool, n = missing_n, replace = TRUE) %>%
      mutate(zone = zone, month = month, y4_hhid = "97-97")
  })
  
  full_data <- bind_rows(data, imputed_rows)
  
  zone_month_counts2 <- full_data %>%
    group_by(zone, month) %>%
    tally(name = "count") %>%
    ungroup()
  still_missing <- all_combos %>%
    left_join(zone_month_counts2, by = c("zone", "month")) %>%
    mutate(count = ifelse(is.na(count), 0, count),
           missing_n = n - count) %>%
    filter(missing_n > 0)
  # Try global pool
  if (nrow(still_missing) > 0) {
    imputed_rows2 <- purrr::pmap_dfr(still_missing, function(zone, month, count, missing_n) {
      pool <- data
      if (nrow(pool) == 0) return(NULL)
      slice_sample(pool, n = missing_n, replace = TRUE) %>%
        mutate(zone = zone, month = month, y4_hhid = "96-96")
    })
    full_data <- bind_rows(full_data, imputed_rows2)
    imputed_rows <- bind_rows(imputed_rows, imputed_rows2)
    # Recheck
    zone_month_counts3 <- full_data %>%
      group_by(zone, month) %>%
      tally(name = "count") %>%
      ungroup()
    still_missing2 <- all_combos %>%
      left_join(zone_month_counts3, by = c("zone", "month")) %>%
      mutate(count = ifelse(is.na(count), 0, count),
             missing_n = n - count) %>%
      filter(missing_n > 0)
    # If still missing, fill with synthetic (all zeros)
    if (nrow(still_missing2) > 0) {
      synthetic_rows <- purrr::pmap_dfr(still_missing2, function(zone, month, count, missing_n) {
        syn <- data.frame(
          y4_hhid = paste0("94-94_", seq_len(missing_n)),
          zone = zone,
          month = month,
          stringsAsFactors = FALSE
        )
        for (col in value_cols) syn[[col]] <- 0
        syn
      })
      full_data <- bind_rows(full_data, synthetic_rows)
      imputed_rows <- bind_rows(imputed_rows, synthetic_rows)
    }
  }
  # Final NA check: replace any accidental NA with 0
  full_data <- full_data %>% mutate(across(all_of(value_cols), ~replace_na(., 0)))
  list(
    imputed_data = full_data,
    imputed_only = imputed_rows
  )
}

# ---- 8. Prepare imputed datasets for each method ----
res1 <- impute_within_zone(boot_ap, n = 10)
boot_ap_within_zone <- res1$imputed_data
imputed_within_zone <- res1$imputed_only

res2 <- impute_across_zones(boot_ap, n = 10)
boot_ap_across_zones <- res2$imputed_data
imputed_across_zones <- res2$imputed_only

# ---- 9. NA check after imputation ----
if (any(is.na(boot_ap_within_zone))) {
  warning("NAs found in boot_ap_within_zone after imputation. These will be replaced with 0.")
  boot_ap_within_zone[is.na(boot_ap_within_zone)] <- 0
}
if (any(is.na(boot_ap_across_zones))) {
  warning("NAs found in boot_ap_across_zones after imputation. These will be replaced with 0.")
  boot_ap_across_zones[is.na(boot_ap_across_zones)] <- 0
}

# # ---- 10. Bootstrap function with mean and sd ----
# # Returns a data.table in LONG form: boot_hhid, month, item, value, sd, zone
# 
# bootstrap_zone_per_synthetic_household_long <- function(df_zone, reps = nreps, value_vars, zone_name) {
#   setDT(df_zone)
#   n_hh <- uniqueN(df_zone$y4_hhid)
#   months <- sort(unique(df_zone$month))
#   items <- value_vars
#   
#   # Results for all iterations (list of data.tables)
#   result_list <- vector("list", reps)
#   for (r in seq_len(reps)) {
#     # Sample n_hh rows with replacement for each month
#     sampled <- df_zone[, .SD[sample(.N, n_hh, replace = TRUE)], by = month][order(month)]
#     sampled[, boot_hhid := rep(seq_len(n_hh), times = length(months))]
#     melted <- melt(sampled, id.vars = c("boot_hhid", "month"), measure.vars = items,
#                    variable.name = "item", value.name = "value")
#     melted[, rep := r]
#     result_list[[r]] <- melted[, .(boot_hhid, month, item, value, rep)]
#     if (r %% 100 == 0) message(sprintf("Bootstrap rep %d/%d for zone %s", r, reps, zone_name))
#   }
#   # Combine and compute mean and sd
#   combined <- rbindlist(result_list)
#   summary_dt <- combined[, .(
#     mean = mean(value, na.rm = TRUE),
#     sd = sd(value, na.rm = TRUE)
#   ), by = .(boot_hhid, month, item)]
#   summary_dt[, zone := zone_name]
#   return(summary_dt[])
# }
# 
# # ---- 11. Main bootstrapping loop for each set ----
# setDT(boot_ap_within_zone)
# setDT(boot_ap_across_zones)
# vars <- value_cols
# nreps <- 100
# set.seed(2535)
# # 
# # # (A) Bootstrapping for within-zone-imputed data, output LONG dt
# # result_list_within_long <- vector("list", length(unique(boot_ap_within_zone$zone)))
# # zone_names_within <- unique(boot_ap_within_zone$zone)
# # names(result_list_within_long) <- zone_names_within
# # for (z in zone_names_within) {
# #   message("Bootstrapping zone (long): ", z)
# #   df_zone <- boot_ap_within_zone[zone == z]
# #   result_list_within_long[[z]] <- bootstrap_zone_per_synthetic_household_long(df_zone, reps = nreps, value_vars = vars, zone_name = z)
# # }
# # boot_hh_mean_within_long <- rbindlist(result_list_within_long)
# # saveRDS(boot_hh_mean_within_long, "2_data/appendix/boot_hh_mean_within_zone_long.RDS", compress = TRUE)
# # 
# # # (B) Bootstrapping for across-zones-imputed data, output LONG dt
# # result_list_across_long <- vector("list", length(unique(boot_ap_across_zones$zone)))
# # zone_names_across <- unique(boot_ap_across_zones$zone)
# # names(result_list_across_long) <- zone_names_across
# # for (z in zone_names_across) {
# #   message("Bootstrapping zone (long): ", z)
# #   df_zone <- boot_ap_across_zones[zone == z]
# #   result_list_across_long[[z]] <- bootstrap_zone_per_synthetic_household_long(df_zone, reps = nreps, value_vars = vars, zone_name = z)
# # }
# # boot_hh_mean_across_long <- rbindlist(result_list_across_long)
# # saveRDS(boot_hh_mean_across_long, "2_data/appendix/boot_hh_mean_across_zones_long.RDS", compress = TRUE)
# 
# # --- Bootstrapping: Within-Zone-Imputed Data (chunked and cached per zone) ---
# 
# # Efficient Bootstrapping and Summarization Script
# # Author: [Your Name]
# # Date: [Today's Date]
# 
# # --- Mosaic (column-wise) Bootstrap for Within and Across Zones ---
# 
# library(data.table)
# library(dplyr)
# 
# # Helper: get n_hh (number of synthetic households per zone) 
# get_n_hh <- function(zone_name, n_hh_zone_allmonths) {
#   n_hh_zone_allmonths %>% filter(zone == zone_name) %>% pull(n)
# }
# 
# # Core mosaic bootstrap: column-wise resampling for one zone and month
# mosaic_bootstrap_zone_month <- function(data, n_hh, n_reps, food_items) {
#   boot_list <- vector("list", n_reps)
#   for (rep in seq_len(n_reps)) {
#     synth_hhs <- replicate(
#       n_hh,
#       {
#         vals <- sapply(food_items, function(col) sample(data[[col]], 1, replace = TRUE))
#         as.list(vals)
#       },
#       simplify = FALSE
#     )
#     synth_dt <- rbindlist(lapply(seq_along(synth_hhs), function(i) {
#       as.data.table(synth_hhs[[i]])[, ID := i]
#     }))
#     synth_dt[, rep := rep]
#     boot_list[[rep]] <- synth_dt
#     if (rep %% 10 == 0) gc()
#   }
#   boot_total <- rbindlist(boot_list)
#   boot_long <- melt(boot_total, id.vars = c("rep", "ID"), variable.name = "item", value.name = "value")
#   boot_long[]
# }
# 
# # --- WITHIN-ZONE MOSAIC BOOTSTRAP ---
# n_reps <- 1000
# set.seed(2535)
# food_items <- value_cols # your columns to bootstrap
# n_hh_zone_allmonths_within <- boot_ap_within_zone %>%
#   group_by(zone) %>%
#   summarise(n = n_distinct(y4_hhid)) %>%
#   as.data.table()
# 
# zone_names_within <- unique(boot_ap_within_zone$zone)
# within_results_list <- list()
# 
# for (zone_name in zone_names_within) {
#   cat("Mosaic-bootstrapping within zone:", zone_name, "\n")
#   zone_data <- boot_ap_within_zone[boot_ap_within_zone$zone == zone_name, ]
#   n_hh <- get_n_hh(zone_name, n_hh_zone_allmonths_within)
#   mosaic_zone_results <- list()
#   for (mo in sort(unique(zone_data$month))) {
#     mo_data <- zone_data[zone_data$month == mo, ]
#     if (n_hh == 0) next
#     mosaic_rep <- mosaic_bootstrap_zone_month(mo_data, n_hh, n_reps, food_items)
#     mosaic_rep[, `:=`(zone = zone_name, month = mo)]
#     mosaic_zone_results[[as.character(mo)]] <- mosaic_rep
#   }
#   if (length(mosaic_zone_results) > 0) {
#     within_results_list[[zone_name]] <- rbindlist(mosaic_zone_results)
#     rm(mosaic_zone_results); gc()
#   }
# }
# mosaic_within_dt <- rbindlist(within_results_list, fill=TRUE)
# 
# # --- ACROSS-ZONES MOSAIC BOOTSTRAP ---
# n_hh_zone_allmonths_across <- boot_ap_across_zones %>%
#   group_by(zone) %>%
#   summarise(n = n_distinct(y4_hhid)) %>%
#   as.data.table()
# 
# zone_names_across <- unique(boot_ap_across_zones$zone)
# across_results_list <- list()
# 
# for (zone_name in zone_names_across) {
#   cat("Mosaic-bootstrapping across zones, zone:", zone_name, "\n")
#   zone_data <- boot_ap_across_zones[boot_ap_across_zones$zone == zone_name, ]
#   n_hh <- get_n_hh(zone_name, n_hh_zone_allmonths_across)
#   mosaic_zone_results <- list()
#   for (mo in sort(unique(zone_data$month))) {
#     mo_data <- zone_data[zone_data$month == mo, ]
#     if (n_hh == 0) next
#     mosaic_rep <- mosaic_bootstrap_zone_month(mo_data, n_hh, n_reps, food_items)
#     mosaic_rep[, `:=`(zone = zone_name, month = mo)]
#     mosaic_zone_results[[as.character(mo)]] <- mosaic_rep
#   }
#   if (length(mosaic_zone_results) > 0) {
#     across_results_list[[zone_name]] <- rbindlist(mosaic_zone_results)
#     rm(mosaic_zone_results); gc()
#   }
# }
# mosaic_across_dt <- rbindlist(across_results_list, fill=TRUE)
# 
# # --- Aggregate to get mean and sd for each zone, ID, month, and item ---
# agg_within <- mosaic_within_dt[
#   , .(
#     mean = mean(value, na.rm = TRUE),
#     sd   = sd(value, na.rm = TRUE)
#   ),
#   by = .(zone, ID, month, item)
# ]
# 
# agg_across <- mosaic_across_dt[
#   , .(
#     mean = mean(value, na.rm = TRUE),
#     sd   = sd(value, na.rm = TRUE)
#   ),
#   by = .(zone, ID, month, item)
# ]
# 
# # Save results
# saveRDS(agg_within, "2_data/appendix/mosaic_boot_within_zones_results_long.RDS")
# saveRDS(agg_across, "2_data/appendix/mosaic_boot_across_zones_results_long.RDS")
