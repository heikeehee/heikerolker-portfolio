# =============================================================================
# clean/animals.R
# PURPOSE: Clean livestock ownership, slaughter and feed survey sections
# INPUT:   raw$animals from 01_load_raw.R
# OUTPUT:  data/processed/clean/animals.rds       (cleaned ownership/slaughter)
#          data/processed/clean/animals_fin.rds   (with derived stock measures)
#          data/processed/clean/excl_animals.csv  (exclusion flags)
#          data/processed/clean/feed.rds          (raw feed practices)
#          data/processed/clean/feed_short.rds    (simplified feed type per hh-animal)
#          data/processed/clean/wa.rds            (carcass breakdown, pre-impute)
#          data/processed/clean/fishes.rds        (fishery)
# SECTION: lf_sec_02 (livestock ownership/slaughter), lf_sec_04 (feed),
#          lf_sec_12 (fishery)
# NOTE:    Feed requirement IMPUTATION (FAO feed tables) is in impute/animals.R
#          Carcass breakdown coefficients are applied here as they derive
#          from reference data (breakdown.xlsx) not from assumptions about
#          individual household behaviour.
# =============================================================================

library(here)
library(tidyverse)
library(data.table)

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "clean"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# SECTION 1: ANIMAL OWNERSHIP AND SLAUGHTER (lf_sec_02)
# =============================================================================

lf_sec_02 <- raw$animals$lf_sec_02
animals   <- clean_up(lf_sec_02)

# Re-attach Stata labels stripped by clean_up()
labfix(lf_sec_02, animals)

animals <- upData(animals,
  rename = .q(
    lf02_01    = ownershp,
    lf02_02    = owned2,
    lf02_03    = owned1,
    lf02_04_1  = ind,
    lf02_04_2  = exotic,
    lf02_05    = born,
    lf02_07    = bought,
    lf02_10    = gift,
    lf02_11    = giver,
    lf02_13    = gifted,
    lf02_14    = recp,
    lf02_16    = disease,
    lf02_19    = theft,
    lf02_22    = injury,
    lf02_25    = sold,
    lf02_28_1  = dest1,
    lf02_28_2  = dest2,
    lf02_30    = slaughter,
    lf02_32    = ssold,
    lf02_31    = weight,
    lf02_34_1  = dest1s,
    lf02_34_2  = dest2s
  ),

  # Replace NA with structural 0 where survey question was answered "no"
  # 🚩 FLAG EXCLUSION: Sentinel 0 applied when gateway question == "no".
  # If a household selected "no" in error (e.g. recall fatigue), these zeros
  # are incorrect. Profile distribution of zeros vs NAs in 05_exclusions_audit.R.
  bought   = ifelse(lf02_06 == "no", 0, bought),
  gift     = ifelse(lf02_09 == "no", 0, gift),
  gifted   = ifelse(lf02_12 == "no", 0, gifted),
  disease  = ifelse(lf02_15 == "no", 0, disease),
  theft    = ifelse(lf02_18 == "no", 0, theft),
  injury   = ifelse(lf02_21 == "no", 0, injury),
  sold     = ifelse(lf02_24 == "no", 0, sold),
  slaughter = ifelse(lf02_29 == "no", 0, slaughter),

  # Current stock: indigenous + exotic breeds
  ind     = ifelse(is.na(ind), 0, ind),
  exotic  = ifelse(is.na(exotic), 0, exotic),
  current = ind + exotic,
  current = ifelse(ownershp == "no", 0, current),

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
    current   = "Number of animals currently owned (ind + exotic)",
    weight    = "Average live weight of slaughtered animals",
    ssold     = "Number of animals slaughtered and sold"
  ),
  units = .q(
    weight = kg
  )
)

# Assign sex where determinable from livestock category name
animals <- animals[, sex := fcase(
  lvstckid == "male calves",   "male",
  lvstckid == "female calves", "female",
  lvstckid == "bulls",         "male",
  lvstckid == "steers",        "male",
  lvstckid == "heifers",       "female",
  lvstckid == "cows",          "female"
)]

# Normalise calves ID (sex information now captured in `sex` column)
animals[, lvstckid := ifelse(lvstckid == "male calves",   "calves", lvstckid)]
animals[, lvstckid := ifelse(lvstckid == "female calves", "calves", lvstckid)]

# Add livestock type groupings
ls_list <- list(
  "large ruminants" = c("bulls", "cows", "steers", "heifers", "calves"),
  "small ruminants" = c("goats", "sheep"),
  "pigs"            = "pigs",
  "poultry"         = c("chickens", "ducks", "other poultry"),
  "other animals"   = c("rabbits", "donkeys", "dogs", "other", "hare")
)

ls_list <- data.table(
  lvstckid = unlist(ls_list),
  type     = rep(names(ls_list), lengths(ls_list))
)

animals <- merge(ls_list, animals, by = "lvstckid")

saveRDS(animals, here::here("data", "processed", "clean", "animals.rds"), compress = TRUE)

# --------------------------------------------------------------------------
# Derived stock measures and exclusion flags
# --------------------------------------------------------------------------
animals_sub <- animals[, .(
  y4_hhid, ownershp, type, lvstckid, sex,
  slaughter, weight, owned1, ind, exotic,
  born, bought, gift, ssold, gifted, sold,
  disease, theft, injury
)]

animals_sub[, type := as.factor(type)]

animals_sub$max_owned <- rowSums(animals_sub[, owned1:gift],    na.rm = TRUE)
animals_sub$all_lost  <- rowSums(animals_sub[, disease:injury], na.rm = TRUE)
animals_sub$current   <- rowSums(animals_sub[, ind:exotic],     na.rm = TRUE)

animals_sub <- upData(animals_sub,
  n_slcons   = slaughter - ssold,             # animals slaughtered but not sold (assumed consumed)
  sl_weight  = slaughter * weight,            # total live weight slaughtered
  sold_weight = ssold * weight,               # live weight of slaughtered animals sold
  cons_weight = n_slcons * weight,            # weight assumed consumed (not sold)
  trans      = sold + gifted,                 # animals in transactions
  all_lost2  = all_lost - theft,              # losses excl. theft
  labels = .q(
    all_lost    = "Animals lost to disease, theft or injury",
    all_lost2   = "Animals lost to disease and injury (excl theft)",
    trans       = "Animals part of transaction (sold, gifted or payment)",
    max_owned   = "Maximum possible number of animals owned at any time",
    current     = "Animals currently owned",
    sl_weight   = "Total live weight of all slaughtered animals",
    sold_weight = "Weight of animals slaughtered and sold",
    cons_weight = "Weight of animals slaughtered and assumed consumed (not sold)"
  )
)

saveRDS(animals_sub, here::here("data", "processed", "clean", "animals_fin.rds"),
        compress = TRUE)

# Exclusion flags
excl_animals <- copy(animals_sub)

top2 <- function(x) quantile(x, probs = 0.98, na.rm = TRUE)
bot2 <- function(x) quantile(x, probs = 0.02, na.rm = TRUE)

excl_animals[, top    := top2(weight),  by = lvstckid]
excl_animals[, bot    := bot2(weight),  by = lvstckid]
excl_animals[, topown := top2(current), by = lvstckid]

excl_animals <- excl_animals[, excl := fcase(
  max_owned < slaughter, "Implausible",  # slaughtered more than ever owned
  ssold > slaughter,     "Implausible",  # sold more than slaughtered
  top < weight,          "Top 2%",
  bot > weight,          "Bottom 2%"
)]

# EXCLUSION: flag rows — profile in 05_exclusions_audit.R
excl_animals <- excl_animals %>%
  select(y4_hhid, item = lvstckid, excl) %>%
  unique()

write.csv(excl_animals,
          here::here("data", "processed", "clean", "excl_animals.csv"),
          row.names = FALSE)

# =============================================================================
# SECTION 2: CARCASS BREAKDOWN (reference data from breakdown.xlsx)
# Applies component fractions (meat, offal, hides, waste) to slaughter weights
# 🚩 FLAG CROSS-SECTION: breakdown.xlsx loaded via raw$ref$breakdown in 01_load_raw.R
# =============================================================================

wa <- copy(animals_sub)

# 🚩 FLAG ASSUMPTION: Carcass breakdown coefficients from:
# @Hal.2020 p.151; @beefyieldguide; @lambyieldguide; @Alexander.2016; @Opio.2013 p.171
# These are literature-derived, not survey-measured. Review if local/regional
# breakdown data becomes available. Especially uncertain: whether Alexander.2016
# edible weight (ew) includes offal — see note in archived 03_Animals.Rmd.
breakdown <- raw$ref$breakdown
setDT(breakdown)

breakdown[, `:=` (
  waste = `Bone meal` + Bloodmeal + `Meat & bonemeal`,
  offal = Offals + Fat
)]

breakdown <- breakdown %>% filter(animal != "Beef")  # Beef handled separately in @Opio.2013
breakdown <- breakdown[, .(
  type, meat = `Raw meat`, waste, offal, hides = `Feather meal/hides`, fcr = FCR_A16, ew = EW_A16
)]

# Balance breakdown to 1.0 (residual allocated to waste)
breakdown <- breakdown %>%
  mutate(waste = waste + (1 - meat - waste - hides - offal))

wa <- breakdown[wa, on = "type"]

wa <- upData(wa,
  meat     = meat     * cons_weight,
  offal    = offal    * cons_weight,
  hides    = hides    * cons_weight,
  inedible = waste    * cons_weight,
  ew       = sl_weight * ew,    # total edible weight of all slaughtered animals
  need     = ew * fcr,          # DM feed needed to produce ew (used in impute/animals.R)
  labels = .q(
    meat     = "Edible quantity of slaughtered animals",
    inedible = "Waste material",
    offal    = "All offal and other edible co-products",
    hides    = "Estimated weight of skin and hides",
    ew       = "Edible weight of all animals slaughtered",
    need     = "kg DM needed to produce EW"
  ),
  units = .q(
    meat     = kg,
    inedible = kg
  ),
  drop = .q(waste, fcr, bot, top, topown)
)

saveRDS(wa, here::here("data", "processed", "clean", "wa.rds"), compress = TRUE)

# =============================================================================
# SECTION 3: LIVESTOCK FEEDING PRACTICES (lf_sec_04)
# Survey-reported primary and secondary feed type by livestock group
# Feed requirement calculation (FAO tables) is in impute/animals.R
# =============================================================================

lf_sec_04 <- raw$animals$lf_sec_04
feed      <- clean_up(lf_sec_04)

labs        <- lapply(lf_sec_04, attr, "label")
labs        <- unlist(labs, use.names = TRUE)
label(feed) <- as.list(labs[match(names(feed), names(feed))])

feed <- upData(feed,
  rename = .q(
    lf04_01_1 = feed1,
    lf04_01_2 = feed2,
    lvstckcat = type
  ),
  labels = .q(
    feed1 = "Major feeding practice",
    feed2 = "Second major feeding practice"
  )
)

saveRDS(feed, here::here("data", "processed", "clean", "feed.rds"), compress = TRUE)

# Simplify: use feed2 where tethering (ambiguous) and feed2 is more informative
# 🚩 FLAG ASSUMPTION: "tethering" replaced with feed2 if available.
# Definition of tethering for feed intake not confirmed in codebook.
# Retained as-is from original script — review before stage 3.
feed[, feed1 := ifelse(feed1 == "tethering" & !is.na(feed2), feed2, feed1)]
f <- feed[, .(y4_hhid, type, feed1)]
f[, type := as.factor(type)]

saveRDS(f, here::here("data", "processed", "clean", "feed_short.rds"), compress = TRUE)

# =============================================================================
# SECTION 4: FISHERY (lf_sec_12)
# =============================================================================

lf_sec_12 <- raw$animals$lf_sec_12

fishes <- lf_sec_12 %>%
  clean_up() %>%
  select(
    y4_hhid,
    species           = lf12_02_2,
    tot.quantity      = lf12_05_1,
    tot.unit          = lf12_05_2,
    wks_fished        = lf12_07,
    quantity          = lf12_08_1,
    unit              = lf12_08_2,
    quant_preserved1  = lf12_10_1, unit_preserved1 = lf12_10_2, mtd_preserved1 = lf12_10_3,
    quant_preserved2  = lf12_10_4, unit_preserved2 = lf12_10_5, mtd_preserved2 = lf12_10_6,
    wks_sales         = lf12_11,
    sold1             = lf12_12_1, sold.unit1 = lf12_12_2, sold.type1 = lf12_12_3,
    sold2             = lf12_12_5, sold.unit2 = lf12_12_6, sold.type2 = lf12_12_7,
    consumed1         = lf12_13_1, consumed.unit1 = lf12_13_2, consumed.type1 = lf12_13_3,
    consumed2         = lf12_13_4, consumed.unit2 = lf12_13_5, consumed.type2 = lf12_13_6
  ) %>%
  mutate(
    tot.quantity = ifelse(is.na(tot.quantity), 0, tot.quantity),
    tot.unit     = ifelse(tot.unit == "kipande", "piece", tot.unit)
  )

# NOTE: fish labour data (lf_sec_09) not integrated — labour variables
# not required for MFA pipeline. Revisit if fish section is expanded.

saveRDS(fishes, here::here("data", "processed", "clean", "fishes.rds"), compress = TRUE)

message("clean/animals.R: all animal outputs saved.")
