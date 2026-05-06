# ------------------------------------------------------------------------------------------------------------
# PROJECT: Food Consumption Data Preparation & Exclusion Pipeline
# PURPOSE: Clean, convert, and prepare food consumption data for analysis (Tanzania LSMS)
# AUTHOR: [Your Name]
# DATE: [Auto-generated or set]
# ------------------------------------------------------------------------------------------------------------

# ---- 0. LOAD LIBRARIES -------------------------------------------------------------------------------------
suppressPackageStartupMessages({
  library(tidyverse)
  library(data.table)
  library(Hmisc)
  library(haven)
  library(readxl)
  library(naniar)
  library(here)
})

# ---- 1. GLOBAL FUNCTIONS & CONSTANTS -----------------------------------------------------------------------
hh_grps <- readRDS("2_data/final/LSMS_items_match_fin.RDS")

hh_grps <- hh_grps %>%
  select(itemcode, group) %>%
  filter(!is.na(itemcode), group != "slaughter") %>%
  arrange(itemcode) %>%
  left_join(shortnames, by = "itemcode") %>%
  distinct(itemcode, .keep_all = TRUE)

# Calculation helpers
sm <- function(x) sum(x, na.rm = TRUE)
rd <- function(df) df %>% dplyr::mutate_if(is.numeric, round, 1)
md <- function(x) median(x, na.rm=TRUE)
mn <- function(x) mean(x, na.rm=TRUE)
t <- 1000

full_overview_hh4 <- read_csv("2_data/results/full_overview_hh4.csv")
incl_3b <- full_overview_hh4 %>% 
  filter(hh_type == "agricultural" & is.na(final_status4)) %>% 
  select(y4_hhid, zone, month) %>% 
  distinct()

# Remove haven labels
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

# Standard cleaning for data.tables
clean_up <- function(df){
  df %>%
    setDT() %>% 
    as_factor() %>%
    mutate(across(where(is.factor), tolower)) %>% 
    mutate_if(is.character, ~na_if(., '')) %>% 
    select(-any_of("occ"))
}

# ---- 2. READ METADATA & ZONE MAPPING -----------------------------------------------------------------------

zones <- list(
  "Lakes" = c("Kagera", "Mara", "Mwanza", "Geita", "Simiyu", "Shinyanga", "Kigoma"),
  "Coastal" = c("Mjini Magharibi", "Kaskazini Pemba", "Kaskazini Unguja", "Kusini Pemba", "Kusini Unguja", "Lindi", "Mtwara", "Morogoro", "Pwani", "Dar Es Salaam", "Mjini/Magharibi Unguja"),
  "Central" = c("Manyara", "Dodoma", "Singida", "Tabora"),
  "Northern Highlands" = c("Arusha", "Kilimanjaro", "Tanga"),
  "Southern Highlands" = c("Iringa", "Njombe", "Ruvuma", "Katavi", "Rukwa", "Mbeya")
)
zones <- data.frame(region = unlist(zones), zone = rep(names(zones), lengths(zones))) %>% setDT()

hh_sec_a <- read_dta("2_data/files/hh_sec_a.dta")
hhA <- hh_sec_a %>%
  select(y4_hhid, region = hh_a01_2, intmonth = hh_a18_2) %>%
  mutate(region = str_to_title(as_factor(region))) %>%
  left_join(zones, by = "region") %>%
  mutate(
    intmonth = case_when(
      y4_hhid == "3662-001" ~ 11,
      y4_hhid == "4211-001" ~ 11,
      TRUE ~ as.numeric(intmonth)
    )
  ) %>% as_tibble()
write_csv(hhA, "2_data/files/hhA.csv")

# ---- 3. CLEAN & STRUCTURE FOOD CONSUMPTION DATA ------------------------------------------------------------

hh_sec_j1 <- read_dta("2_data/files/hh_sec_j1.dta")
recall <- clean_up(hh_sec_j1) %>%
  zap_labels()

# Standardize variable names and set 0 for not consumed
names_map <- c(
  hh_j01 = "consumed", hh_j02_2 = "quantity", hh_j03_2 = "purchases",
  hh_j04 = "value", hh_j04_1 = "source", hh_j05_2 = "production", hh_j06_2 = "gifts",
  hh_j02_1 = "unit", hh_j03_1 = "u_bought", hh_j05_1 = "u_produced", hh_j06_1 = "u_gifts"
)
recall <- upData(
  recall,
  rename = as.list(names_map),
  quantity = ifelse(consumed == "no", 0, quantity),
  purchases = ifelse(consumed == "no", 0, purchases),
  production = ifelse(consumed == "no", 0, production),
  gifts = ifelse(consumed == "no", 0, gifts),
  labels = .q(
    consumed = 'Item consumed',
    quantity = 'Quantity of item consumed in the household',
    purchases = 'Quantity of item purchased',
    value = 'Expenditure on item from purchase',
    source = 'Source of purchase',
    production = 'Quantity of item from own production',
    gifts = 'Quantity of item from gifts',
    unit = 'Unit of consumption'
  )
)

# ---- 4. CONVERT ALL UNITS TO KILOGRAMS ---------------------------------------------------------------------

# Define conversion factors for all handled units/items
unit_conv <- tribble(
  ~unit, ~itemcode, ~conv,
  "litre", "fresh milk", 1.08,
  "pieces", "eggs", 0.04126,
  "litre", "milk products (like cream, cheese, yoghurt etc)", 1.01,
  "litre", "cooking oil", 0.9,
  "litre", "bottled/canned soft drinks (soda, juice, water)", 1,
  "litre", "bottled beer", 1,
  "litre", "local brews", 1,
  "litre", "honey, syrups, jams, marmalade, jellies, canned fruits", 1.43,
  "litre", "buns, cakes and biscuits", 0.02,
  "pieces", "bread", 0.5,
  "pieces", "coconuts (mature/immature)", 0.8,
  "pieces", "sweets", 0.05,
  "millilitre", "cooking oil", 0.001,
  "millilitre", "fresh milk", 0.001,
  "millilitre", "milk products (like cream, cheese, yoghurt etc)", 0.001,
  "millilitre", "bottled/canned soft drinks (soda, juice, water)", 0.001,
  "millilitre", "honey, syrups, jams, marmalade, jellies, canned fruits", 0.001,
  "millilitre", "wine and spirits", 0.001,
  "millilitre", "bottled beer", 0.001,
  "millilitre", "local brews", 0.001,
  "millilitre", "prepared tea, coffee", 0.001,
  "millilitre", "peas, beans, lentils and other pulses", 0.001,
  "pieces", "bottled/canned soft drinks (soda, juice, water)", 0.355,
  "litre", "butter, margarine, ghee and other fat products", 0.959,
  "litre", "sweet potatoes", 0.66,
  "litre", "canned, dried and wild vegetables", 0.3
) %>% mutate(unit = as.factor(unit))


# Remove all labels from all columns
recall[] <- lapply(recall, function(x) {
  if ("labelled" %in% class(x)) as.character(as_factor(x)) else x
})

# Alternatively, use your clear.labels() function if it covers all columns:
recall <- clear.labels(recall)

# Helper for conversion by source with correct join_by syntax and flagging logic for NA units
apply_conversion <- function(data, var, source_unit_var = "unit", item_var = "itemcode") {
  # Dynamically construct join_by for left_join
  join_by <- setNames(c("itemcode", "unit"), c(item_var, source_unit_var))
  # Flag: If unit is NA and value > 0, mark for review
  flag_var <- paste0(var, "_flagged")
  data[[flag_var]] <- ifelse(is.na(data[[source_unit_var]]) & !is.na(data[[var]]) & data[[var]] > 0, TRUE, FALSE)
  
  # Conversion logic
  data <- left_join(data, unit_conv, by = join_by)
  data$conv <- dplyr::case_when(
    data[[source_unit_var]] == "litre" ~ data$conv,
    data[[source_unit_var]] == "pieces" ~ data$conv,
    data[[source_unit_var]] == "millilitre" ~ data$conv,
    data[[source_unit_var]] == "kilograms" ~ 1,
    data[[source_unit_var]] == "grams" ~ 0.001,
    is.na(data[[source_unit_var]]) ~ 0,
    TRUE ~ data$conv
  )
  # Do the conversion
  data[[paste0(var, "_kg")]] <- as.numeric(data[[var]]) * data$conv
  # Clean up
  data$conv <- NULL
  data
}

# Ensure all relevant variables are numeric in recall
recall <- recall %>%
  mutate(across(
    c(quantity, purchases, production, gifts, value),
    ~ suppressWarnings(as.numeric(.))
  ))

# Run conversions using the updated helper
recall1 <- apply_conversion(
  data = recall,
  var = "quantity",
  source_unit_var = "unit",
  item_var = "itemcode"
)
recall2 <- apply_conversion(
  data = recall,
  var = "purchases",
  source_unit_var = "u_bought",
  item_var = "itemcode"
)
recall3 <- apply_conversion(
  data = recall,
  var = "production",
  source_unit_var = "u_produced",
  item_var = "itemcode"
)
recall4 <- apply_conversion(
  data = recall,
  var = "gifts",
  source_unit_var = "u_gifts",
  item_var = "itemcode"
)

# Merge the "_kg" and flagged columns back into recall
recall_final <- recall %>%
  left_join(select(recall1, y4_hhid, itemcode, quantity_kg, quantity_flagged), by = c("y4_hhid", "itemcode")) %>%
  left_join(select(recall2, y4_hhid, itemcode, purchases_kg, purchases_flagged), by = c("y4_hhid", "itemcode")) %>%
  left_join(select(recall3, y4_hhid, itemcode, production_kg, production_flagged), by = c("y4_hhid", "itemcode")) %>%
  left_join(select(recall4, y4_hhid, itemcode, gifts_kg, gifts_flagged), by = c("y4_hhid", "itemcode"))

# this may require attention: 6 households affected, 2 for production
recall_final %>% filter(quantity_flagged | purchases_flagged | production_flagged | gifts_flagged)

# Finalize
recall <- recall_final

# Save
saveRDS(recall, file = "2_data/files/recall_converted.RDS", compress = TRUE)

# ---- 5. AGGREGATE AND ATTACH FCT CALORIES ------------------------------------------------------------------

# Only keep relevant "_kg" variables, rename for clarity
rec7d <- recall %>%
  select(y4_hhid, itemcode, ends_with("_kg")) %>%
  dplyr::rename(
    quant = quantity_kg,
    produced = production_kg,
    purch = purchases_kg,
    gifts = gifts_kg
  ) %>%
  clear.labels()

# Load FCT table and attach calories
fct <- read_excel("2_data/reference/TFNC_NCT_NTPS20_v.3.0.0.xlsx") %>%
  mutate(item_desc = str_to_lower(item_desc))
rec7d_fct <- rec7d %>%
  left_join(select(fct, itemcode = item_desc, ENERCkcal), by = "itemcode") %>%
  mutate(quant_kcal = quant * 10 * ENERCkcal)

fwrite(rec7d_fct, "2_data/files/recall_7d_fct.csv")

rec7d_kcal <- rec7d_fct %>%
  group_by(y4_hhid) %>%
  summarise(
    quant_kcal = sum(quant_kcal, na.rm = TRUE)
  )

# ---- 6. MERGE WITH HOUSEHOLD DEMOGRAPHICS ------------------------------------------------------------------

aFMe_summaries <- read_csv("2_data/final/aFMe_summaries.csv")
rec7d_kcal_afme <- rec7d_kcal %>%
  left_join(select(aFMe_summaries, y4_hhid, amehh, afehh, hh_persons), by = "y4_hhid") %>%
  filter(!is.na(amehh)) %>%
  mutate(
    ame_kcald = quant_kcal / 7 / amehh,
    afe_kcald = quant_kcal / 7 / afehh,
    pp_kcald = quant_kcal / 7 / hh_persons
  )

# ---- 7. EXCLUSION LOGIC & STATUS ---------------------------------------------------------------------------

# 1) Extreme daily kcal exclusions
rec7d_excl1 <- rec7d_kcal_afme %>%
  mutate(
    excl = ifelse(afe_kcald < 500 | afe_kcald > 5000, "Consumption unrealistic", NA)
  ) %>%
  select(y4_hhid, excl)

# 2) No consumption
excl_cons <- rec7d %>%
  group_by(y4_hhid) %>%
  summarise(cons = sm(quant)) %>%
  filter(cons == 0) %>%
  mutate(excl = "No consumption") %>%
  select(y4_hhid, excl)

# 3) Item-level plausibility
rec7d_excl <- rec7d %>%
  mutate(
    smd = purch + produced + gifts,
    quant12 = quant * 1.2,
    excl = case_when(
      smd > quant * 1.3 ~ "Consumption insufficient",
      smd < quant * 0.7 ~ "Consumption unaccounted",
      purch > quant12 | produced > quant12 | gifts > quant12 ~ "Data inconsistent",
      TRUE ~ NA_character_
    )
  ) %>%
  select(y4_hhid, excl)

# Combine exclusions
excl_list_recall <- bind_rows(excl_cons, rec7d_excl, rec7d_excl1) %>%
  mutate(excl = ifelse(y4_hhid %in% c("3800-001", "4786-001"), "Unclear why", excl))
write_csv(excl_list_recall, "2_data/files/excl_list_recall.csv")

# Final status list
excl1 <- excl_list_recall %>%
  filter(!is.na(excl)) %>%
  distinct(y4_hhid) %>%
  mutate(status = "excluded") %>%
  setDT()

allhhids <- hh_sec_a %>% select(y4_hhid) %>% unique() %>% setDT()
incl <- allhhids[!excl1, on = .(y4_hhid)][, status := "included"]
exclA <- bind_rows(excl1, incl)
write_csv(exclA, "2_data/appendix/excl_recall.csv")

# ---- 8. FINAL STATUS WITH ZONE AND MERGE EXCLUSIONS --------------------------------------------------------

excl_3a <- read_csv("2_data/final/hhs_3a.csv")
excl_3b <- exclA %>%
  rename(status_recall = status) %>%
  full_join(excl_3a, by = "y4_hhid")

full_overview_hh4 <- hhA %>%
  select(y4_hhid, region, zone, month = intmonth) %>%
  full_join(excl_3b, by = "y4_hhid") %>%
  mutate(final_status4 = ifelse(status == "excluded" | status_recall == "excluded", "excluded", NA_character_))
fwrite(full_overview_hh4, "2_data/results/full_overview_hh4.csv")

write_csv(excl_3b, "2_data/final/excl_3b.csv")
write_csv(excl_3b, "2_data/results/excl_3b.csv")

# ---- 9. PER-AFE MONTHLY AGGREGATES -------------------------------------------------------------------------
afe_mopres_hh <- read_csv("2_data/results/afe_mopres_hh.csv") 

recmo <- rec7d %>%
  full_join(select(afe_mopres_hh, y4_hhid, afe_7d), by = "y4_hhid") %>%
  mutate(
    across(quant:gifts, ~ .x / afe_7d, .names = "{.col}_afe"),
    across(quant_afe:gifts_afe, ~ .x * 4.3, .names = "{.col}_mo")
  )

shortnames <- read_excel("2_data/reference/shortnames.xlsx")

recmo1 <- recmo %>%
  left_join(shortnames, by = "itemcode") %>%
  left_join(select(hhA, y4_hhid, zone, intmonth), by = "y4_hhid") %>%
  rename(month = intmonth) %>% 
  left_join(select(hh_grps, shortnames, group), by = "shortnames")

fwrite(recmo1, "2_data/results/recall_details.csv")


# ---- 10. FISH DATA CLEANING (FOR MATCHING TO MAIN SURVEY) --------------------------------------------------

lf_sec_12 <- read_dta("2_data/files/lf_sec_12.dta") %>%
  setDT() %>%
  as_factor() %>%
  mutate(across(where(is.factor), tolower)) %>%
  mutate_if(is.character, ~na_if(., '')) %>%
  select(-any_of("occ"))

fishes <- lf_sec_12 %>%
  select(y4_hhid, species = lf12_02_2, tot.quantity = lf12_05_1, tot.unit = lf12_05_2, wks_fished = lf12_07,
         quantity = lf12_08_1, unit = lf12_08_2, quant_preserved1 = lf12_10_1, unit_preserved1 = lf12_10_2,
         mtd_preserved1 = lf12_10_3, quant_preserved2 = lf12_10_4, unit_preserved2 = lf12_10_5,
         mtd_preserved2 = lf12_10_6, wks_sales = lf12_11, sold1 = lf12_12_1, sold.unit1 = lf12_12_2,
         sold.type1 = lf12_12_3, sold2 = lf12_12_5, sold.unit2 = lf12_12_6, sold.type2 = lf12_12_7,
         consumed1 = lf12_13_1, consumed.unit1 = lf12_13_2, consumed.type1 = lf12_13_3,
         consumed2 = lf12_13_4, consumed.unit2 = lf12_13_5, consumed.type2 = lf12_13_6) %>%
  mutate(
    tot.quantity = replace_na(tot.quantity, 0),
    tot.unit = ifelse(tot.unit == "kipande", "piece", tot.unit)
  )
saveRDS(fishes, "2_data/final/fishes.RDS", compress = TRUE)

fish_consumption <- fishes %>%
  mutate(
    consumed1 = ifelse(is.na(consumed1) & tot.quantity > 0, 0, consumed1),
    consumed2 = ifelse(is.na(consumed2) & tot.quantity > 0, 0, consumed2),
    consumed = consumed1 + consumed2,
    tot.consumed = consumed * wks_fished
  ) %>%
  mutate(
    item1 = ifelse(consumed.type1 == "fresh" | consumed.type2 == "fresh", "fresh fish", NA_character_),
    item2 = ifelse((consumed.type1 != "fresh" & !is.na(consumed.type1)) | (consumed.type2 != "fresh" & !is.na(consumed.type2)), "processed fish", NA_character_),
    unit.cons = ifelse(consumed.unit1 == "kilogram" & (consumed.unit2 == "kilogram" | is.na(consumed.unit2)), "kilogram", "other")
  ) %>%
  select(y4_hhid, tot.quantity, tot.unit, tot.consumed, unit.cons, item1, item2)
saveRDS(fish_consumption, "2_data/final/fish_consumption.RDS", compress = TRUE)

# ---- 11. ERROR CHECKING UTILITY FOR ALL KEY DATAFRAMES -----------------------------------------------------

error_check_comp_quant <- function(df, name = "comp.quant") {
  cat("==== Error Check for", name, "====\n")
  print(str(df))
  print(summary(df))
  if ("tbl" %in% class(df)) print(glimpse(df))
  if (requireNamespace("naniar", quietly = TRUE)) {
    print(naniar::miss_var_summary(df))
    print(naniar::miss_case_summary(df))
  } else {
    print(colSums(is.na(df)))
  }
  n_dup <- sum(duplicated(df))
  cat("Number of fully duplicated rows:", n_dup, "\n")
  if (n_dup > 0) print(df[duplicated(df), ])
  if (all(c("zone", "group") %in% names(df))) {
    n_key_dup <- sum(duplicated(df[, c("zone", "group")]))
    cat("Number of duplicated (zone, group) pairs:", n_key_dup, "\n")
    if (n_key_dup > 0) print(df[duplicated(df[, c("zone", "group")]), ])
  }
  num_cols <- names(df)[sapply(df, is.numeric)]
  if (length(num_cols) > 0) {
    for (col in num_cols) {
      cat(paste("Column:", col, "\n"))
      print(summary(df[[col]]))
      if (any(is.infinite(df[[col]]), na.rm = TRUE)) cat("Infinite values found in", col, "\n")
      if (any(df[[col]] < 0, na.rm = TRUE) && !grepl("diff|difference", col)) cat("Warning: Negative values found in", col, "\n")
      if (any(abs(df[[col]]) > 1e6, na.rm = TRUE)) cat("Warning: Very large values found in", col, "\n")
    }
  }
  if ("produced4cons" %in% names(df) && "perc_dif" %in% names(df)) {
    zeros <- df$produced4cons == 0 & df$consumedFprod == 0
    if (any(zeros, na.rm = TRUE)) {
      cat("Rows with both produced4cons and consumedFprod zero:\n")
      print(df[zeros, ])
    }
  }
  if ("perc_dif" %in% names(df)) {
    if (any(abs(df$perc_dif) > 1000, na.rm = TRUE)) {
      cat("Warning: Extreme perc_dif values found:\n")
      print(df[abs(df$perc_dif) > 1000, ])
    }
  }
  key_cols <- intersect(names(df), c("zone", "group", "new_name_ag", "new_name_hh"))
  for (col in key_cols) {
    if (any(is.na(df[[col]]))) {
      cat("Warning: NA in key column:", col, "\n")
      print(df[is.na(df[[col]]), ])
    }
  }
  cat("==== End Error Check for", name, "====\n\n")
}

# ---- END ---------------------------------------------------------------------------------------------------