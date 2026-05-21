# =============================================================================
# clean/animals.R
# PURPOSE: Clean livestock ownership, slaughter and feed survey sections
# INPUT:   raw$animals from 01_load_raw.R
# OUTPUT:  data/processed/01/clean/animals.rds
#          data/processed/01/clean/animals_fin.rds
#          data/processed/01/clean/excl_animals.csv
#          data/processed/01/clean/feed.rds
#          data/processed/01/clean/feed_short.rds
#          data/processed/01/clean/wa.rds
#          data/processed/01/clean/fishes.rds
# SECTION: lf_sec_02 (livestock ownership/slaughter), lf_sec_04 (feed),
#          lf_sec_12 (fishery)
# NOTE:    Clean stage only: standardise, derive diagnostics, and flag issues.
#          Any value-changing repair or fallback belongs in impute/animals.R.
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "01", "clean"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# SECTION 1: ANIMAL OWNERSHIP AND SLAUGHTER (lf_sec_02)
# =============================================================================

lf_sec_02 <- raw$animals$lf_sec_02
animals <- clean_up(lf_sec_02)
labfix(lf_sec_02, animals)

animals <- upData(
  animals,
  rename = .q(
    lf02_01   = ownershp,
    lf02_02   = owned2,
    lf02_03   = owned1,
    lf02_04_1 = ind,
    lf02_04_2 = exotic,
    lf02_05   = born,
    lf02_07   = bought,
    lf02_10   = gift,
    lf02_11   = giver,
    lf02_13   = gifted,
    lf02_14   = recp,
    lf02_16   = disease,
    lf02_19   = theft,
    lf02_22   = injury,
    lf02_25   = sold,
    lf02_28_1 = dest1,
    lf02_28_2 = dest2,
    lf02_30   = slaughter,
    lf02_32   = ssold,
    lf02_31   = weight,
    lf02_34_1 = dest1s,
    lf02_34_2 = dest2s
  ),
  labels = .q(
    ownershp  = "Animals owned in past year",
    owned2    = "Number of animals owned two years ago",
    owned1    = "Number of animals owned 12 mo ago",
    ind       = "Number of indigenous breeds currently owned",
    exotic    = "Number of exotic breeds currently owned",
    born      = "Number of animals born in past 12 mo",
    bought    = "Number of animals bought alive in past 12 mo",
    gift      = "Number of animals received as payment or gift",
    giver     = "Giver of animals as gift or payment",
    gifted    = "Number of animals given as gift or payment",
    recp      = "Recipient of animals gifted",
    disease   = "Number of animals lost to disease",
    theft     = "Number of animals lost to theft",
    injury    = "Number of animals lost to injury",
    sold      = "Number of animals sold alive",
    dest1     = "First buyer of animals",
    dest2     = "Second buyer of animals",
    slaughter = "Number of animals slaughtered",
    dest1s    = "First buyer of slaughtered animals",
    dest2s    = "Second buyer of slaughtered animals",
    weight    = "Average live weight of slaughtered animals",
    ssold     = "Number of animals slaughtered and sold"
  ),
  units = .q(weight = kg)
)

# FLAG F1: duplicate animal rows by household and livestock item.
n_flag_dup_animals <- animals[, .N, by = .(y4_hhid, lvstckid)][N > 1, .N]
animals[, flag_dup_animals := fifelse(duplicated(paste(y4_hhid, lvstckid)) | duplicated(paste(y4_hhid, lvstckid), fromLast = TRUE), 1L, 0L)]
message("flag_dup_animals: ", n_flag_dup_animals,
        " duplicated (y4_hhid, lvstckid) combinations in lf_sec_02")

# FLAG F2: gateway questions imply a zero count later, but that repair is deferred to impute.
animals[, flag_bought_zero_from_gate := fifelse(lf02_06 == "no", 1L, 0L)]
animals[, flag_gift_zero_from_gate := fifelse(lf02_09 == "no", 1L, 0L)]
animals[, flag_gifted_zero_from_gate := fifelse(lf02_12 == "no", 1L, 0L)]
animals[, flag_disease_zero_from_gate := fifelse(lf02_15 == "no", 1L, 0L)]
animals[, flag_theft_zero_from_gate := fifelse(lf02_18 == "no", 1L, 0L)]
animals[, flag_injury_zero_from_gate := fifelse(lf02_21 == "no", 1L, 0L)]
animals[, flag_sold_zero_from_gate := fifelse(lf02_24 == "no", 1L, 0L)]
animals[, flag_slaughter_zero_from_gate := fifelse(lf02_29 == "no", 1L, 0L)]

n_flag_bought_zero_from_gate <- animals[flag_bought_zero_from_gate == 1L, .N]
n_flag_gift_zero_from_gate <- animals[flag_gift_zero_from_gate == 1L, .N]
n_flag_gifted_zero_from_gate <- animals[flag_gifted_zero_from_gate == 1L, .N]
n_flag_disease_zero_from_gate <- animals[flag_disease_zero_from_gate == 1L, .N]
n_flag_theft_zero_from_gate <- animals[flag_theft_zero_from_gate == 1L, .N]
n_flag_injury_zero_from_gate <- animals[flag_injury_zero_from_gate == 1L, .N]
n_flag_sold_zero_from_gate <- animals[flag_sold_zero_from_gate == 1L, .N]
n_flag_slaughter_zero_from_gate <- animals[flag_slaughter_zero_from_gate == 1L, .N]

message("flag_bought_zero_from_gate: ", n_flag_bought_zero_from_gate, " rows where bought gate is 'no'")
message("flag_gift_zero_from_gate: ", n_flag_gift_zero_from_gate, " rows where gift gate is 'no'")
message("flag_gifted_zero_from_gate: ", n_flag_gifted_zero_from_gate, " rows where gifted gate is 'no'")
message("flag_disease_zero_from_gate: ", n_flag_disease_zero_from_gate, " rows where disease gate is 'no'")
message("flag_theft_zero_from_gate: ", n_flag_theft_zero_from_gate, " rows where theft gate is 'no'")
message("flag_injury_zero_from_gate: ", n_flag_injury_zero_from_gate, " rows where injury gate is 'no'")
message("flag_sold_zero_from_gate: ", n_flag_sold_zero_from_gate, " rows where sold gate is 'no'")
message("flag_slaughter_zero_from_gate: ", n_flag_slaughter_zero_from_gate, " rows where slaughter gate is 'no'")

# FLAG F3: classify current stock and ownership inconsistency for review only.
animals[, flag_current_missing := fifelse(ownershp == "yes" & is.na(ind) & is.na(exotic), 1L, 0L)]
animals[, flag_no_ownership := fifelse(ownershp == "no", 1L, 0L)]
animals[, flag_current_components_missing := fifelse(ownershp != "no" & is.na(ind) & is.na(exotic), 1L, 0L)]

n_flag_current_missing <- animals[flag_current_missing == 1L, .N]
n_flag_no_ownership <- animals[flag_no_ownership == 1L, .N]
n_flag_current_components_missing <- animals[flag_current_components_missing == 1L, .N]

message("flag_current_missing: ", n_flag_current_missing, " rows where ind and exotic are both missing")
message("flag_no_ownership: ", n_flag_no_ownership, " rows where ownershp is 'no'")
message("flag_current_components_missing: ", n_flag_current_components_missing,
        " rows where ownershp is not 'no' but ind and exotic are both missing")

# Standardise numeric columns without overwriting values.
animals[, `:=`(
  ind = as.numeric(ind),
  exotic = as.numeric(exotic),
  bought = as.numeric(bought),
  gift = as.numeric(gift),
  gifted = as.numeric(gifted),
  disease = as.numeric(disease),
  theft = as.numeric(theft),
  injury = as.numeric(injury),
  sold = as.numeric(sold),
  slaughter = as.numeric(slaughter)
)]

animals[, sex := fcase(
  lvstckid == "male calves",   "male",
  lvstckid == "female calves", "female",
  lvstckid == "bulls",         "male",
  lvstckid == "steers",        "male",
  lvstckid == "heifers",       "female",
  lvstckid == "cows",          "female",
  default = NA_character_
)]

animals[, lvstckid := fifelse(lvstckid %in% c("male calves", "female calves"), "calves", lvstckid)]

ls_list <- list(
  "large ruminants" = c("bulls", "cows", "steers", "heifers", "calves"),
  "small ruminants" = c("goats", "sheep"),
  "pigs"            = "pigs",
  "poultry"         = c("chickens", "ducks", "other poultry"),
  "other animals"   = c("rabbits", "donkeys", "dogs", "other", "hare")
)

ls_list <- data.table(
  lvstckid = unlist(ls_list),
  type = rep(names(ls_list), lengths(ls_list))
)

animals <- merge(ls_list, animals, by = "lvstckid")

saveRDS(animals, here::here("data", "processed", "01", "clean", "animals.rds"), compress = TRUE)

# =============================================================================
# FLAG SUMMARY
# =============================================================================

flag_cols <- names(animals)[grepl("^flag_", names(animals))]
flag_summary <- data.table(
  flag = flag_cols,
  n = vapply(flag_cols, function(col) animals[get(col) == 1L, .N], integer(1))
)[order(-n)]

message("----- Flag summary: animals -----")
print(flag_summary)

readr::write_csv(
  as.data.frame(flag_summary),
  here::here("data", "processed", "01", "clean", "animals_flag_summary.csv")
)

# =============================================================================
# SECTION 1B: DERIVED STOCK MEASURES AND EXCLUSION FLAGS
# =============================================================================

animals_sub <- animals[, .(
  y4_hhid, ownershp, type, lvstckid, sex,
  slaughter, weight, owned1, ind, exotic,
  born, bought, gift, ssold, gifted, sold,
  disease, theft, injury
)]

animals_sub[, max_owned := rowSums(.SD, na.rm = TRUE),
            .SDcols = c("owned1", "born", "bought", "gift")]

animals_sub[, all_lost := rowSums(.SD, na.rm = TRUE),
            .SDcols = c("disease", "theft", "injury")]

animals_sub[, current := rowSums(.SD, na.rm = TRUE),
            .SDcols = c("ind", "exotic")]

animals_sub[, n_slcons := slaughter - ssold]
animals_sub[, `:=`(
  sl_weight = slaughter * weight,
  sold_weight = ssold * weight,
  cons_weight = n_slcons * weight,
  trans = sold + gifted,
  all_lost2 = all_lost - theft
)]

animals_sub[, `:=`(
  flag_slaughter_gt_max_owned = fifelse(!is.na(max_owned) & !is.na(slaughter) & slaughter > max_owned, 1L, 0L),
  flag_ssold_gt_slaughter = fifelse(!is.na(ssold) & !is.na(slaughter) & ssold > slaughter, 1L, 0L),
  flag_current_missing_sub = fifelse(is.na(current), 1L, 0L),
  flag_milk_animal = fifelse(ownershp == "yes" & (type == "large ruminants" & sex == "female") | lvstckid == "goats" | lvstckid == "sheep", 1L, 0L) # include donkeys?
)]

n_flag_slaughter_gt_max_owned <- animals_sub[flag_slaughter_gt_max_owned == 1L, .N]
n_flag_ssold_gt_slaughter <- animals_sub[flag_ssold_gt_slaughter == 1L, .N]
n_flag_current_missing_sub <- animals_sub[flag_current_missing_sub == 1L, .N]
n_flag_milk_animal <- animals_sub[flag_milk_animal == 1L, .N]

message("flag_slaughter_gt_max_owned: ", n_flag_slaughter_gt_max_owned,
        " rows where slaughter exceeds maximum observed ownership")
message("flag_ssold_gt_slaughter: ", n_flag_ssold_gt_slaughter,
        " rows where slaughtered-sold exceeds slaughtered total")
message("flag_current_missing_sub: ", n_flag_current_missing_sub,
        " rows where current stock measure is missing")
message("flag_milk_animal: ", n_flag_milk_animal,
        " rows with animals that can be milked")

animals_sub[, type := as.factor(type)]

saveRDS(animals_sub, here::here("data", "processed", "01", "clean", "animals_fin.rds"), compress = TRUE)

flag_cols <- names(animals_sub)[grepl("^flag_", names(animals_sub))]
flag_summary <- data.table(
  flag = flag_cols,
  n = vapply(flag_cols, function(col) animals_sub[get(col) == 1L, .N], integer(1))
)[order(-n)]

message("----- Flag summary: animals_fin -----")
print(flag_summary)

readr::write_csv(
  as.data.frame(flag_summary),
  here::here("data", "processed", "01", "clean", "animals_fin_flag_summary.csv")
)

# =============================================================================
# SECTION 2: CARCASS BREAKDOWN (reference data from breakdown.xlsx)
# =============================================================================

wa <- copy(animals_sub)

breakdown <- raw$ref$breakdown
setDT(breakdown)

breakdown[, `:=`(
  waste = `Bone meal` + Bloodmeal + `Meat & bonemeal`,
  offal = Offals + Fat
)]

breakdown <- breakdown[animal != "Beef"]
breakdown <- breakdown[, .(
  type,
  meat = `Raw meat`,
  waste,
  offal,
  hides = `Feather meal/hides`,
  fcr = FCR_A16,
  ew = EW_A16
)]

breakdown[, waste := waste + (1 - meat - waste - hides - offal)]

wa <- breakdown[wa, on = "type"]

wa[, `:=`(
  meat = meat * cons_weight,
  offal = offal * cons_weight,
  hides = hides * cons_weight,
  inedible = waste * cons_weight,
  ew = sl_weight * ew,
  need = ew * fcr
)]

wa[, `:=`(
  flag_weight_missing = fifelse(is.na(weight) & slaughter > 0, 1L, 0L),
  flag_breakdown_type_missing = fifelse(is.na(type), 1L, 0L)
)]

n_flag_weight_missing <- wa[flag_weight_missing == 1L, .N]
n_flag_breakdown_type_missing <- wa[flag_breakdown_type_missing == 1L, .N]

message("flag_weight_missing: ", n_flag_weight_missing, " rows where slaughter weight is missing")
message("flag_breakdown_type_missing: ", n_flag_breakdown_type_missing,
        " rows where livestock type did not match carcass breakdown reference")

saveRDS(wa, here::here("data", "processed", "01", "clean", "wa.rds"), compress = TRUE)

flag_cols <- names(wa)[grepl("^flag_", names(wa))]
flag_summary <- data.table(
  flag = flag_cols,
  n = vapply(flag_cols, function(col) wa[get(col) == 1L, .N], integer(1))
)[order(-n)]

message("----- Flag summary: wa -----")
print(flag_summary)

readr::write_csv(
  as.data.frame(flag_summary),
  here::here("data", "processed", "01", "clean", "wa_flag_summary.csv")
)

# =============================================================================
# SECTION 3: LIVESTOCK FEEDING PRACTICES (lf_sec_04)
# =============================================================================

lf_sec_04 <- raw$animals$lf_sec_04
feed <- clean_up(lf_sec_04)
labfix(lf_sec_04, feed)

feed <- upData(
  feed,
  rename = .q(
    lf04_01_1 = feed1_raw,
    lf04_01_2 = feed2_raw,
    lvstckcat = type
  ),
  labels = .q(
    feed1_raw = "Major feeding practice, as reported",
    feed2_raw = "Second major feeding practice, as reported"
  )
)

feed_levels <- c(
  "only feeding (no grazing/scavenging)",
  "mainly grazing/scavenging w/ some feeding",
  "only grazing/scavenging",
  "mainly feeding w/ some grazing/scavenging",
  "tethering"
)

animals_hh <- animals_sub %>%
  filter(ownershp == "yes") %>%
  select(y4_hhid, type) %>%
  distinct() %>%
  mutate(flag_expected_feed_section = 1L)

feed <- feed %>%
  full_join(animals_hh, by = c("y4_hhid", "type")) %>%
  mutate(
    flag_feed_only = fifelse(is.na(flag_expected_feed_section) & (!is.na(feed1_raw) | !is.na(feed2_raw)), 1L, 0L),
    flag_animal_only = fifelse(!is.na(flag_expected_feed_section) & is.na(feed1_raw) & is.na(feed2_raw), 1L, 0L),
    flag_both_sections = fifelse(!is.na(flag_expected_feed_section) & (!is.na(feed1_raw) | !is.na(feed2_raw)), 1L, 0L),
    flag_true_na_feed1 = fifelse(!is.na(flag_expected_feed_section) & is.na(feed1_raw) & is.na(feed2_raw), 1L, 0L),
    flag_feed1_unexpected = fifelse(!is.na(feed1_raw) & !(feed1_raw %in% feed_levels), 1L, 0L),
    flag_feed2_unexpected = fifelse(!is.na(feed2_raw) & !(feed2_raw %in% feed_levels), 1L, 0L)
  )

n_flag_feed_only <- feed[flag_feed_only == 1L, .N]
n_flag_animal_only <- feed[flag_animal_only == 1L, .N]
n_flag_both_sections <- feed[flag_both_sections == 1L, .N]
n_flag_true_na_feed1 <- feed[flag_true_na_feed1 == 1L, .N]
n_flag_feed1_unexpected <- feed[flag_feed1_unexpected == 1L, .N]
n_flag_feed2_unexpected <- feed[flag_feed2_unexpected == 1L, .N]

message("flag_feed_only: ", n_flag_feed_only, " rows where feed exists without matching owned-animal record")
message("flag_animal_only: ", n_flag_animal_only, " rows where owned-animal record exists without feed data")
message("flag_both_sections: ", n_flag_both_sections, " rows where both sections matched")
message("flag_true_na_feed1: ", n_flag_true_na_feed1, " rows where both feed fields are missing on matched livestock")
message("flag_feed1_unexpected: ", n_flag_feed1_unexpected, " rows where primary feed practice is unrecognised")
message("flag_feed2_unexpected: ", n_flag_feed2_unexpected, " rows where secondary feed practice is unrecognised")

saveRDS(feed, here::here("data", "processed", "01", "clean", "feed.rds"), compress = TRUE)

feed_short <- feed[, .(
  y4_hhid,
  type,
  feed1_raw,
  feed2_raw,
  flag_expected_feed_section,
  flag_feed_only,
  flag_animal_only,
  flag_both_sections,
  flag_true_na_feed1,
  flag_feed1_unexpected,
  flag_feed2_unexpected
)]

saveRDS(feed_short, here::here("data", "processed", "01", "clean", "feed_short.rds"), compress = TRUE)

flag_cols <- names(feed_short)[grepl("^flag_", names(feed_short))]
flag_summary <- data.table(
  flag = flag_cols,
  n = vapply(flag_cols, function(col) feed_short[get(col) == 1L, .N], integer(1))
)[order(-n)]

message("----- Flag summary: feed_short -----")
print(flag_summary)

readr::write_csv(
  as.data.frame(flag_summary),
  here::here("data", "processed", "01", "clean", "feed_short_flag_summary.csv")
)

saveRDS(feed_short, here::here("data", "processed", "01", "clean", "feed_short.rds"), compress = TRUE)

flag_cols <- names(feed_short)[grepl("^flag_", names(feed_short))]
flag_summary <- data.table(
  flag = flag_cols,
  n = vapply(flag_cols, function(col) feed_short[get(col) == 1L, .N], integer(1))
)[order(-n)]

message("----- Flag summary: feed_short -----")
print(flag_summary)

readr::write_csv(
  as.data.frame(flag_summary),
  here::here("data", "processed", "01", "clean", "feed_short_flag_summary.csv")
)

# =============================================================================
# SECTION 4: FISHERY (lf_sec_12)
# =============================================================================

lf_sec_12 <- raw$animals$lf_sec_12

fishes <- lf_sec_12 %>%
  clean_up() %>%
  select(
    y4_hhid,
    species = lf12_02_2,
    tot.quantity = lf12_05_1,
    tot.unit = lf12_05_2,
    wks_fished = lf12_07,
    quantity = lf12_08_1,
    unit = lf12_08_2,
    quant_preserved1 = lf12_10_1, unit_preserved1 = lf12_10_2, mtd_preserved1 = lf12_10_3,
    quant_preserved2 = lf12_10_4, unit_preserved2 = lf12_10_5, mtd_preserved2 = lf12_10_6,
    wks_sales = lf12_11,
    sold1 = lf12_12_1, sold.unit1 = lf12_12_2, sold.type1 = lf12_12_3,
    sold2 = lf12_12_5, sold.unit2 = lf12_12_6, sold.type2 = lf12_12_7,
    consumed1 = lf12_13_1, consumed.unit1 = lf12_13_2, consumed.type1 = lf12_13_3,
    consumed2 = lf12_13_4, consumed.unit2 = lf12_13_5, consumed.type2 = lf12_13_6
  )

fishes[, flag_tot_quantity_missing := fifelse(is.na(tot.quantity) & !is.na(species), 1L, 0L)]
fishes[, flag_tot_unit_missing := fifelse(is.na(tot.unit) & !is.na(species), 1L, 0L)]

n_flag_tot_quantity_missing <- fishes[flag_tot_quantity_missing == 1L, .N]
n_flag_tot_unit_missing <- fishes[flag_tot_unit_missing == 1L, .N]

message("flag_tot_quantity_missing: ", n_flag_tot_quantity_missing, " rows where total quantity is missing")
message("flag_tot_unit_missing: ", n_flag_tot_unit_missing, " rows where total unit is missing")

saveRDS(fishes, here::here("data", "processed", "01", "clean", "fishes.rds"), compress = TRUE)

flag_cols <- names(fishes)[grepl("^flag_", names(fishes))]
flag_summary <- data.table(
  flag = flag_cols,
  n = vapply(flag_cols, function(col) fishes[get(col) == 1L, .N], integer(1))
)[order(-n)]

message("----- Flag summary: fishes -----")
print(flag_summary)

readr::write_csv(
  as.data.frame(flag_summary),
  here::here("data", "processed", "01", "clean", "fishes_flag_summary.csv")
)

message("clean/animals.R: all animal outputs saved.")