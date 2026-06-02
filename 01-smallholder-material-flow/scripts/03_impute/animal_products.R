# =============================================================================
# impute/animal_products.R
# PURPOSE: Apply repair, fallback, and allocation rules for animal products
# INPUT:   clean/produce.rds, clean/hides.rds, clean/mass_eggs.rds,
#          clean/animals_fin.rds, clean/feed_short.rds, clean/wa.rds
# OUTPUT:  data/processed/01/impute/produce_imputed.rds
#          data/processed/01/impute/hides_imputed.rds
#          data/processed/01/impute/mass_hides_imputed.rds
#          data/processed/01/impute/mass_eggs_imputed.rds
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "01", "impute"), showWarnings = FALSE, recursive = TRUE)

produce <- readRDS(here::here("data", "processed", "01", "clean", "produce.rds"))
hides <- readRDS(here::here("data", "processed", "01", "clean", "hides.rds"))
mass_eggs <- readRDS(here::here("data", "processed", "01", "clean", "mass_eggs.rds"))
animals_fin <- readRDS(here::here("data", "processed", "01", "clean", "animals_fin.rds"))
feed_short <- readRDS(here::here("data", "processed", "01", "clean", "feed_short.rds"))
wa <- readRDS(here::here("data", "processed", "01", "clean", "wa.rds"))

produce[, produced := fifelse(lf08_01 == "no", 0, as.numeric(produced_raw))]
produce[, sold := fifelse(lf08_04 == "no", 0, as.numeric(sold_raw))]
produce[, flag_produced_imputed_zero := fifelse(lf08_01 == "no", 1L, 0L)]
produce[, flag_sold_imputed_zero := fifelse(lf08_04 == "no", 1L, 0L)]
produce[, produced_annual := produced * as.numeric(length)]
produce[, sold_annual := sold]
produce[, flag_produced_annualised := fifelse(!is.na(produced) & !is.na(length), 1L, 0L)]

message("flag_produced_imputed_zero: ", produce[flag_produced_imputed_zero == 1L, .N], " rows where production gate is 'no' and produced is set to zero")
message("flag_sold_imputed_zero: ", produce[flag_sold_imputed_zero == 1L, .N], " rows where sales gate is 'no' and sold is set to zero")
message("flag_produced_annualised: ", produce[flag_produced_annualised == 1L, .N], " rows where produced was annualised using length")

hides[, flag_hides_weight_repair := fifelse(is.na(weight) & !is.na(produced_raw), 1L, 0L)]
hides[, weight_imputed := fifelse(is.na(weight), produced_raw, weight)]
message("flag_hides_weight_repair: ", hides[flag_hides_weight_repair == 1L, .N], " rows where hides weight needs repair")

hime <- hides[, .(y4_hhid, pprod = produced_raw, sold2 = sold_raw)]
meat <- wa[slaughter > 0, .(y4_hhid, type, lvstckid, slaughter, weight, hides, sold_weight)]
meat_type <- unique(meat[, .(y4_hhid, type)])

hime <- merge(hime, meat_type, by = "y4_hhid", all.x = TRUE)
meatt <- meat[, lapply(.SD, sm), .SDcols = is.numeric, by = .(y4_hhid, type)]
himeatt <- merge(hime, meatt, by = c("y4_hhid", "type"), all = TRUE)

himeatt[, flag_hides_type_unmatched := fifelse(is.na(type), 1L, 0L)]
himeatt[, flag_hides_allocation_missing := fifelse(is.na(pprod) & !is.na(y4_hhid), 1L, 0L)]
himeatt[, rel_prod := fifelse(is.na(pprod) | is.na(produced_raw), NA_real_, pprod / produced_raw)]
himeatt[, flag_rel_prod_imputed := fifelse(!is.na(rel_prod), 1L, 0L)]

message("flag_hides_type_unmatched: ", himeatt[flag_hides_type_unmatched == 1L, .N], " rows where hides records do not match an animal type")
message("flag_hides_allocation_missing: ", himeatt[flag_hides_allocation_missing == 1L, .N], " rows where hides allocation is missing")
message("flag_rel_prod_imputed: ", himeatt[flag_rel_prod_imputed == 1L, .N], " rows where relative hides production was derived")

mass_hides_long <- himeatt
mass_hides <- himeatt[!is.na(type) & type %in% c("small ruminants", "large ruminants")]

mass_eggs_imputed <- copy(mass_eggs)
mass_eggs_imputed[, flag_eggs_feed_missing := fifelse(is.na(feed1_raw) | is.na(feed), 1L, 0L)]
mass_eggs_imputed[, feed := fifelse(is.na(feed), 0.5, feed)]
mass_eggs_imputed[, grazed := fifelse(is.na(grazed), 0.5, grazed)]
mass_eggs_imputed[, flag_eggs_feed_defaulted := fifelse(is.na(feed) | is.na(grazed), 1L, 0L)]

message("flag_eggs_feed_missing: ", mass_eggs_imputed[flag_eggs_feed_missing == 1L, .N], " rows where egg feed allocation is missing")
message("flag_eggs_feed_defaulted: ", mass_eggs_imputed[flag_eggs_feed_defaulted == 1L, .N], " rows where egg feed/grazing split was defaulted")

flag_summary <- function(dt) {
  flag_cols <- names(dt)[grepl("^flag_", names(dt))]
  data.table(
    flag = flag_cols,
    n = vapply(flag_cols, function(col) dt[get(col) == 1L, .N], integer(1))
  )[order(-n)]
}

readr::write_csv(as.data.frame(flag_summary(produce)), here::here("data", "processed", "01", "impute", "produce_flag_summary.csv"))
readr::write_csv(as.data.frame(flag_summary(hides)), here::here("data", "processed", "01", "impute", "hides_flag_summary.csv"))
readr::write_csv(as.data.frame(flag_summary(mass_hides_long)), here::here("data", "processed", "01", "impute", "mass_hides_long_flag_summary.csv"))
readr::write_csv(as.data.frame(flag_summary(mass_eggs_imputed)), here::here("data", "processed", "01", "impute", "mass_eggs_flag_summary.csv"))

saveRDS(produce, here::here("data", "processed", "01", "impute", "produce_imputed.rds"), compress = TRUE)
saveRDS(hides, here::here("data", "processed", "01", "impute", "hides_imputed.rds"), compress = TRUE)
saveRDS(mass_hides_long, here::here("data", "processed", "01", "impute", "mass_hides_imputed.rds"), compress = TRUE)
saveRDS(mass_eggs_imputed, here::here("data", "processed", "01", "impute", "mass_eggs_imputed.rds"), compress = TRUE)

message("impute/animal_products.R: animal products imputed and saved.")