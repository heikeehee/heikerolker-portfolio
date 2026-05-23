# =============================================================================
# clean/animal_products.R
# PURPOSE: Clean livestock product survey section (eggs, hides, other products)
# INPUT:   raw$animal_products from 01_load_raw.R
#          clean/animals_fin.rds, clean/feed_short.rds, clean/wa.rds
# OUTPUT:  data/processed/01/clean/produce.rds
#          data/processed/01/clean/hides.rds
#          data/processed/01/clean/mass_eggs.rds
#          data/processed/01/clean/excl_eggs.csv
# SECTION: lf_sec_08 — livestock products (eggs, hides, honey, wool, etc.)
# NOTE:    Clean stage only. Standardise, derive diagnostics, and flag issues.
#          Any repair, fallback, or allocation rule belongs in impute/animal_products.R.
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "01", "clean"), showWarnings = FALSE, recursive = TRUE)

lf_sec_08 <- raw$animal_products$lf_sec_08
produce <- clean_up(lf_sec_08)

produce <- upData(
  produce,
  rename = .q(
    lf08_02   = length,
    lf08_03_1 = produced_raw,
    lf08_03_2 = unit_raw,
    lf08_05_1 = sold_raw,
    lf08_05_2 = unitsold_raw,
    lf08_06   = value,
    lf08_07_1 = buyer1,
    lf08_07_2 = buyer2
  ),
  labels = .q(
    length = "Number of months produced in past 12 mo",
    produced_raw = "Average quantity produced per month, as reported",
    unit_raw = "Unit of production, as reported",
    sold_raw = "Quantity sold in last 12 months, as reported",
    value = "Total value of sales in past 12 months"
  )
)

produce[, flag_produced_gate := fifelse(lf08_01 == "yes", 1L, 0L)]
produce[, flag_sold_gate := fifelse(lf08_04 == "yes", 1L, 0L)]
produce[, flag_true_na_produced := fifelse(lf08_01 == "yes" & is.na(produced_raw), 1L, 0L)]
produce[, flag_true_na_unit := fifelse(lf08_01 == "yes" & is.na(unit_raw), 1L, 0L)]
produce[, flag_true_na_sold := fifelse(lf08_04 == "yes" & is.na(sold_raw), 1L, 0L)]
produce[, flag_true_na_unitsold := fifelse(lf08_04 == "yes" & is.na(unitsold_raw), 1L, 0L)]

allowed_units <- c("kgs", "kg", "pieces", "piece", "litres", "liters", "litre", "liter")
produce[, flag_unit_unexpected := fifelse(!is.na(unit_raw) & !(tolower(unit_raw) %in% allowed_units), 1L, 0L)]

message("flag_produced_gate: ", produce[flag_produced_gate == 1L, .N], " rows where production gate is 'yes'")
message("flag_sold_gate: ", produce[flag_sold_gate == 1L, .N], " rows where sales gate is 'yes'")
message("flag_true_na_produced: ", produce[flag_true_na_produced == 1L, .N], " rows where produced_raw is genuinely missing")
message("flag_true_na_unit: ", produce[flag_true_na_unit == 1L, .N], " rows where unit_raw is genuinely missing")
message("flag_true_na_sold: ", produce[flag_true_na_sold == 1L, .N], " rows where sold_raw is genuinely missing")
message("flag_true_na_unitsold: ", produce[flag_true_na_unitsold == 1L, .N], " rows where unitsold_raw is genuinely missing")
message("flag_unit_unexpected: ", produce[flag_unit_unexpected == 1L, .N], " rows where unit_raw is not recognised")

saveRDS(produce, here::here("data", "processed", "01", "clean", "produce.rds"), compress = TRUE)

flag_summary <- data.table(
  flag = names(produce)[grepl("^flag_", names(produce))],
  n = vapply(names(produce)[grepl("^flag_", names(produce))], function(col) produce[get(col) == 1L, .N], integer(1))
)[order(-n)]

message("----- Flag summary: produce -----")
print(flag_summary)

readr::write_csv(
  as.data.frame(flag_summary),
  here::here("data", "processed", "01", "clean", "produce_flag_summary.csv")
)

hides <- produce[productid == "skin / hides"]

hides[, flag_hides_section_present := 1L]
hides[, flag_hides_true_na := fifelse(is.na(produced_raw) & is.na(sold_raw), 1L, 0L)]

message("flag_hides_true_na: ", hides[flag_hides_true_na == 1L, .N], " rows where hides production and sales are both genuinely missing")

saveRDS(hides, here::here("data", "processed", "01", "clean", "hides.rds"), compress = TRUE)

flag_summary <- data.table(
  flag = names(hides)[grepl("^flag_", names(hides))],
  n = vapply(names(hides)[grepl("^flag_", names(hides))], function(col) hides[get(col) == 1L, .N], integer(1))
)[order(-n)]

message("----- Flag summary: hides -----")
print(flag_summary)

readr::write_csv(
  as.data.frame(flag_summary),
  here::here("data", "processed", "01", "clean", "hides_flag_summary.csv")
)

animals_fin <- readRDS(here::here("data", "processed", "01", "clean", "animals_fin.rds"))
feed_short  <- readRDS(here::here("data", "processed", "01", "clean", "feed_short.rds"))

animals_poultry_hh <- animals_fin[type == "poultry", .(
  max_owned = sum(max_owned, na.rm = TRUE),
  current = sum(current, na.rm = TRUE),
  n_poultry_rows = .N
), by = y4_hhid]

feed_poultry_hh <- feed_short[type == "poultry", .(
  feed1_raw = first(feed1_raw),
  feed2_raw = first(feed2_raw),
  flag_feed_only = max(flag_feed_only, na.rm = TRUE),
  flag_animal_only = max(flag_animal_only, na.rm = TRUE),
  flag_both_sections = max(flag_both_sections, na.rm = TRUE),
  flag_feed1_unexpected = max(flag_feed1_unexpected, na.rm = TRUE),
  flag_feed2_unexpected = max(flag_feed2_unexpected, na.rm = TRUE)
), by = y4_hhid]

chicken <- data.table(
  feed1 = c(
    "only feeding (no grazing/scavenging)",
    "mainly grazing/scavenging w/ some feeding",
    "only grazing/scavenging",
    "mainly feeding w/ some grazing/scavenging",
    "tethering"
  ),
  type = "poultry",
  feed = c(1, 0.4, 0, 0.6, 0.5),
  grazed = c(0, 0.6, 1, 0.4, 0.5)
)

eggs <- produce[productid == "eggs", .(
  y4_hhid,
  productid,
  produced_kg = as.numeric(produced_raw),
  sold_kg = as.numeric(sold_raw),
  egg_length = length
)]

ef <- merge(eggs, animals_poultry_hh, by = "y4_hhid", all.x = TRUE)
ef <- merge(ef, feed_poultry_hh, by = "y4_hhid", all.x = TRUE)
ef <- merge(ef, chicken, by.x = "feed1_raw", by.y = "feed1", all.x = TRUE)

ef[, flag_eggs_gate := fifelse(produced_kg>0, 1L, 0L)]
ef[, flag_eggs_section_misalignment := fifelse(is.na(type) & produced_kg > 0, 1L, 0L)]
ef[, flag_eggs_feed_alignment_missing := fifelse(is.na(feed1_raw) & is.na(feed2_raw) & produced_kg > 0, 1L, 0L)]
ef[, flag_egg_feed_category_missing := fifelse(!is.na(feed1_raw) & !(feed1_raw %in% chicken$feed1), 1L, 0L)]
ef[, flag_chicken_no_egg := fifelse(max_owned > 0 & is.na(produced_kg), 1L, 0L)]
ef[, flag_egg_unaccounted := fifelse(!is.na(sold_kg) & produced_kg-sold_kg != 0, 1L, 0L)]
ef[, flag_egg_overuse := fifelse(!is.na(sold_kg) & produced_kg<sold_kg, 1L, 0L)]

message("flag_eggs_gate: ", ef[flag_eggs_gate == 1L, .N], " rows where eggs produced")
message("flag_eggs_section_misalignment: ", ef[flag_eggs_section_misalignment == 1L, .N], " rows where eggs have no poultry support match")
message("flag_eggs_feed_alignment_missing: ", ef[flag_eggs_feed_alignment_missing == 1L, .N], " rows where eggs have no matching feed practice")
message("flag_egg_feed_category_missing: ", ef[flag_egg_feed_category_missing == 1L, .N], " rows where egg feed category does not match the poultry crosswalk")
message("flag_chicken_no_egg: ", ef[flag_chicken_no_egg == 1L, .N], " rows where chicken exist but no eggs")
message("flag_egg_unaccounted: ", ef[flag_egg_unaccounted == 1L, .N], " rows where egg produced - egg sold not zero")
message("flag_egg_overuse: ", ef[flag_egg_overuse == 1L, .N], " rows where egg sold exceed eggs produced")


ef <- chicken[ef, on = .(feed1 = feed1_raw, type)]

mass_eggs <- ef
saveRDS(mass_eggs, here::here("data", "processed", "01", "clean", "mass_eggs.rds"), compress = TRUE)


flag_summary <- data.table(
  flag = names(mass_eggs)[grepl("^flag_", names(mass_eggs))],
  n = vapply(names(mass_eggs)[grepl("^flag_", names(mass_eggs))], function(col) mass_eggs[get(col) == 1L, .N], integer(1))
)[order(-n)]

message("----- Flag summary: mass_eggs -----")
print(flag_summary)

readr::write_csv(
  as.data.frame(flag_summary),
  here::here("data", "processed", "01", "clean", "mass_eggs_flag_summary.csv")
)

message("clean/animal_products.R: animal product outputs saved.")