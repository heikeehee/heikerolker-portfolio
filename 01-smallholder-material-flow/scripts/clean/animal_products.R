# =============================================================================
# clean/animal_products.R
# PURPOSE: Clean livestock product survey section (eggs, hides, other products)
# INPUT:   raw$animal_products from 01_load_raw.R
#          clean/animals_fin.rds, clean/feed_short.rds, clean/wa.rds
#          (cross-section dependencies from clean/animals.R)
# OUTPUT:  data/processed/clean/produce.rds           (all animal products, raw clean)
#          data/processed/clean/hides.rds             (hides extracted from produce)
#          data/processed/clean/mass_hides.rds        (hides matched to animal type)
#          data/processed/clean/mass_hides_long.rds   (extended hides detail)
#          data/processed/clean/mass_eggs.rds         (eggs with feed estimate)
#          data/processed/clean/excl_eggs.csv         (exclusion flags for eggs)
# SECTION: lf_sec_08 — livestock products (eggs, hides, honey, wool, etc.)
# NOTE:    Egg consumption allocation (recall-based imputation) is flagged
#          and left for stage 3; an explicit placeholder is included.
# =============================================================================

library(here)
library(tidyverse)
library(data.table)

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))
source(here::here("01-smallholder-material-flow", "scripts", "functions.R"))

dir.create(here::here("data", "processed", "clean"), showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# SECTION 1: ANIMAL PRODUCTS — base cleaning (lf_sec_08)
# =============================================================================

lf_sec_08 <- raw$animal_products$lf_sec_08
produce   <- clean_up(lf_sec_08)

produce <- upData(produce,
  rename = .q(
    lf08_02    = length,
    lf08_03_1  = produced,
    lf08_03_2  = unit,
    lf08_05_1  = sold,
    lf08_05_2  = unitsold,
    lf08_06    = value,
    lf08_07_1  = buyer1,
    lf08_07_2  = buyer2
  ),
  # Replace NA with structural 0 where gateway question was "no"
  produced = ifelse(lf08_01 == "no", 0, produced),
  sold     = ifelse(lf08_04 == "no", 0, sold),
  sold     = as.numeric(sold),

  labels = .q(
    length   = "Number of months produced in past 12 mo",
    produced = "Average quantity produced per month",
    unit     = "Unit of production",
    sold     = "Quantity sold in last 12 months",
    value    = "Total value of sales in past 12 months"
  )
)

saveRDS(produce, here::here("data", "processed", "clean", "produce.rds"), compress = TRUE)

# =============================================================================
# SECTION 2: HIDES
# Match hides production to slaughtered animal types
# 🚩 FLAG CROSS-SECTION: wa (carcass breakdown) and animals_fin (slaughter counts)
# loaded from clean/animals.R outputs. Run clean/animals.R first.
# =============================================================================

wa          <- readRDS(here::here("data", "processed", "clean", "wa.rds"))
animals_sub <- readRDS(here::here("data", "processed", "clean", "animals_fin.rds"))

# Extract hides from produce
hides <- produce[productid == "skin / hides"]

# Slaughter info (animals slaughtered for household consumption, not sold)
ah <- wa[, .(y4_hhid, type, lvstckid, slaughter, hides, ssold)]
ah[, slaughter := slaughter - ssold]  # only animals slaughtered for assumed consumption
ah[, slaughter := adlab(slaughter, "Animals slaughtered for assumed consumption only")]

# Collapse to household-type level (hides are recorded at hh level)
ah <- ah[, lapply(.SD, sm), .SDcols = is.numeric, by = .(y4_hhid, type)]

# Pivot slaughter counts wide by animal type
sl <- ah %>%
  spread(type, slaughter) %>%
  select(!c(poultry, `other animals`, pigs, hides)) %>%
  dplyr::rename(lgrm = `large ruminants`, smrm = `small ruminants`) %>%
  mutate(
    smrm = as.numeric(replace_na(smrm, 0)),
    lgrm = as.numeric(replace_na(lgrm, 0))
  ) %>%
  group_by(y4_hhid) %>%
  summarise(smrm = sum(smrm), lgrm = sum(lgrm))

# Pivot hides weights wide
hi <- ah %>%
  select(!slaughter) %>%
  spread(type, hides) %>%
  select(!c(poultry, `other animals`, pigs)) %>%
  dplyr::rename(hlgrm = `large ruminants`, hsmrm = `small ruminants`)

# Merge hides with slaughter counts and hide weights
hides <- merge(hides, sl, by = "y4_hhid", all = TRUE)
hides <- merge(hides, hi, by = "y4_hhid", all = TRUE)

# Annual production in pieces and kg/litre
hides[, `:=` (
  pieces = ifelse(unit == "pieces", produced * length, NA),
  total  = ifelse(unit == "kgs" | unit == "litres", produced * length, NA)
)]
hides[, `:=` (pieces = as.double(pieces), total = as.double(total))]

# 🚩 FLAG ASSUMPTION: Allocation logic assigns hides to animal type based on
# matching reported piece count to slaughter numbers. Multiple fcase() branches
# handle partial matching. Logic is heuristic — not codebook-derived.
# Review each branch with a domain expert before stage 3.
hides[, `:=` (
  weight = fcase(
    pieces <= lgrm,                               hlgrm,
    pieces <= smrm,                               hsmrm,
    pieces > smrm & (is.na(lgrm) | lgrm == 0),   hsmrm / pieces * smrm,
    pieces > lgrm & (is.na(smrm) | smrm == 0),   hlgrm / pieces * lgrm,
    pieces >= (smrm + lgrm),                      hsmrm + hlgrm,
    total  <= hlgrm & hsmrm == 0,                 total,
    total  <= hsmrm & hlgrm == 0,                 total,
    total  >  hlgrm & hsmrm == 0,                 hlgrm,
    total  >  hsmrm & hlgrm == 0,                 hsmrm,
    total  <  (hsmrm + hlgrm),                    total,
    total  >  (hsmrm + hlgrm),                    hsmrm + hlgrm
  ),
  type = fcase(
    pieces <= lgrm,                               "large ruminants",
    pieces <= smrm,                               "small ruminants",
    pieces > smrm & (is.na(lgrm) | lgrm == 0),   "small ruminants",
    pieces > lgrm & (is.na(smrm) | smrm == 0),   "large ruminants",
    total  <= hlgrm & hsmrm == 0,                 "large ruminants",
    total  <= hsmrm & hlgrm == 0,                 "small ruminants",
    total  >= hlgrm & hsmrm == 0,                 "large ruminants",
    total  >= hsmrm & hlgrm == 0,                 "small ruminants"
  )
)]

# Proportion sold
hides[, perc_sold := fcase(
  unit == "kgs" | unit == "litres", sold / total,
  unit == "pieces",                  sold / pieces
)]
hides[, weight_sold := ifelse(sold == 0, 0, perc_sold * weight)]
hides[, weight_sold := ifelse(is.na(weight_sold), 0, weight_sold)]
hides[, missing     := weight - weight_sold]

hides <- upData(hides,
  labels = .q(
    total       = "Total quantity produced annually (kg or litre)",
    perc_sold   = "Percentage of skins/hides production sold",
    pieces      = "Annual production of hides in pieces as reported",
    missing     = "Quantities unaccounted, assumed consumed"
  ),
  units = .q(
    total       = kg,
    weight_sold = kg
  ),
  drop = .q(smrm, lgrm, hsmrm, hlgrm, lf08_08_2, lf08_08_1, lf08_06,
            unit, unitsold, lf08_04, length, produced, lf08_01, sold)
)

hides <- upData(hides,
  rename = .q(weight = produced, weight_sold = sold),
  drop   = .q(pieces, total, perc_sold)
)

# EXCLUSION: keep only hides with positive production
# 🚩 FLAG EXCLUSION: hides[produced == 0] dropped. Confirm these are structural
# zeros (no slaughter → no hides) not missing data — profile in 05_exclusions_audit.R
hides <- hides[produced > 0]

saveRDS(hides, here::here("data", "processed", "clean", "hides.rds"), compress = TRUE)

# --------------------------------------------------------------------------
# Assemble hides with slaughter info (mass_hides_long / mass_hides)
# --------------------------------------------------------------------------

slaughter <- wa[slaughter > 0]
meat      <- slaughter[, .(y4_hhid, type, lvstckid, slaughter, weight, hides, sold_weight)]
hime      <- hides[, .(y4_hhid, type, pprod = produced, sold2 = sold, missing)]
hime      <- hime[pprod > 0]
meatt     <- meat[, lapply(.SD, sm), .SDcols = is.numeric, by = .(y4_hhid, type)]
himeatt   <- merge(hime, meatt, by = c("y4_hhid", "type"), all = TRUE)

# Households with no matched animal type — split across ruminants manually
hides_hh  <- himeatt[is.na(type)]
hides_hh  <- hides_hh[, .(y4_hhid, pprod, sold2, missing)]
rumsonly  <- meatt[type == "large ruminants" | type == "small ruminants"]
manualfix <- rumsonly[hides_hh, on = .(y4_hhid)]
sums      <- manualfix[, lapply(.SD, sm), .SDcols = is.numeric, by = .(y4_hhid)]

manualfix[, `:=` (pprod_new = hides, perc_sold = sold2 / pprod / 2)]

# 🚩 FLAG ASSUMPTION: Three households where hides cannot be algorithmically
# split between large/small ruminants — assigned by manual inspection of raw data.
# Flag for review if raw data or slaughter records change.
manualfix$pprod_new[which(manualfix$y4_hhid == "7294-001" & manualfix$type == "large ruminants")] <- 1.5
manualfix$pprod_new[which(manualfix$y4_hhid == "7294-001" & manualfix$type == "small ruminants")] <- 1.5
manualfix$pprod_new[which(manualfix$y4_hhid == "8014-001" & manualfix$type == "large ruminants")] <- 0
manualfix$pprod_new[which(manualfix$y4_hhid == "8014-001" & manualfix$type == "small ruminants")] <- 5
manualfix$pprod_new[which(manualfix$y4_hhid == "4764-001" & manualfix$type == "large ruminants")] <- 1
manualfix$pprod_new[which(manualfix$y4_hhid == "4764-001" & manualfix$type == "small ruminants")] <- 1

manualfix[, sold_new := perc_sold * pprod_new]
manualfix[, .q(pprod, sold2, perc_sold) := NULL]
manualfix <- upData(manualfix, rename = .q(sold_new = sold2, pprod_new = pprod))
manualfix[, sold2    := replace_na(sold2, 0)]
manualfix[, missing  := pprod - sold2]

# Combine manually fixed with remainder
new  <- dplyr::anti_join(himeatt, manualfix, by = c("y4_hhid", "type"))
new  <- new[, .(y4_hhid, type, weight, hides, sold_weight, pprod, sold2, missing)]
new[, missing := as.double(missing)]
meat_combined <- bind_rows(manualfix, new)

# Merge with slaughter component info
meat_sl    <- slaughter[, .(type, y4_hhid, meat, offal, hides, inedible)]
meat_sl    <- meat_sl[, lapply(.SD, sm), .SDcols = is.numeric, by = .(y4_hhid, type)]

mass_hides_long <- upData(meat_combined,
  labels = .q(
    weight      = "Total weight of animals slaughtered",
    hides       = "Estimate of total hides",
    sold_weight = "Live weight of animals slaughtered",
    pprod       = "Weight of hides produced from slaughter",
    sold2       = "Weight of hides sold",
    missing     = "Hides not sold (assumed for household)"
  )
)

mass_hides <- mass_hides_long %>%
  left_join(select(hides, y4_hhid, produced), by = "y4_hhid") %>%
  mutate(
    rel_prod = pprod / produced,
    rel_prod = ifelse(produced > 0 & is.na(rel_prod), 0, rel_prod)
  ) %>%
  select(!c(produced, weight, sold_weight)) %>%
  filter((type == "small ruminants" | type == "large ruminants") & !is.na(pprod))

mass_hides[, rel_prod := adlab(rel_prod,
  "Proportion of hides produced from total (i.e. not slaughter)")]

saveRDS(mass_hides,      here::here("data", "processed", "clean", "mass_hides.rds"),      compress = TRUE)
saveRDS(mass_hides_long, here::here("data", "processed", "clean", "mass_hides_long.rds"), compress = TRUE)

# =============================================================================
# SECTION 3: EGGS
# 🚩 FLAG CROSS-SECTION: animals_fin and feed_short from clean/animals.R required.
# Run clean/animals.R before this section.
# =============================================================================

animals_fin <- readRDS(here::here("data", "processed", "clean", "animals_fin.rds"))
f           <- readRDS(here::here("data", "processed", "clean", "feed_short.rds"))

# Feed coefficients for poultry (backyard, @MacLeod.2013 p.107)
# 🚩 FLAG ASSUMPTION: Feed fractions from @MacLeod.2013 p.107 — not survey-derived.
# Same values used in impute/animals.R for consistency.
chicken <- data.table(
  feed1  = c("only feeding (no grazing/scavenging)",
             "mainly grazing/scavenging w/ some feeding",
             "only grazing/scavenging",
             "mainly feeding w/ some grazing/scavenging",
             "tethering"),
  type   = "poultry",
  feed   = c(1, 0.4, 0, 0.6, 0.5),
  grazed = c(0, 0.6, 1, 0.4, 0.5)
)

# Poultry ownership summary for exclusion checks
ae <- animals_fin[, .(y4_hhid, type, lvstckid, current, max_owned)]
ae <- ae[type == "poultry"]
ae <- ae[, lapply(.SD, sm), .SDcols = is.numeric, by = .(y4_hhid, type)]

produce[, produced := as.numeric(produced)]
produce[, sold     := as.numeric(sold)]
e <- produce[productid == "eggs"]

# Unit conversion: pieces/litres → kg
# 🚩 FLAG UNIT: Egg weight 41.26g from @MacLeod.2013 p.105 — SSA average.
# Not Tanzania-specific; may differ by breed/management. Flag for review.
e <- upData(e,
  produced_new = fcase(
    unit == "kgs",    produced * length,
    unit == "pieces", produced * 41.26 / 1000 * length,
    unit == "litres", produced * 1.03 * length
  ),
  sold_new = fcase(
    unitsold == "kgs",    sold,
    unitsold == "pieces", sold * 41.26 / 1000,
    unitsold == "litres", sold * 1.03
  ),
  sold_new = ifelse(sold == 0, 0, sold_new),
  n_eggs   = produced_new / 0.04126 / length,
  N_eggs   = produced_new / 0.04126,
  labels = .q(
    produced_new = "Annual quantity produced",
    sold_new     = "Annual quantity sold",
    n_eggs       = "Number of eggs per month",
    N_eggs       = "Total quantity of eggs produced"
  ),
  units = .q(
    produced_new = kg,
    sold_new     = kg
  )
)

cols_to_zero <- c("produced_new", "sold_new", "n_eggs", "N_eggs")
e[, (cols_to_zero) := lapply(.SD, function(x) ifelse(is.na(x), 0, x)),
  .SDcols = cols_to_zero]

# Exclusions
eggs <- e[, .(y4_hhid, productid, produced = produced_new, sold = sold_new,
              n_eggs, N_eggs, length)]
eggs <- ae[eggs, on = .(y4_hhid)]
eggs$mean  <- rowMeans(eggs[, c("current", "max_owned")], na.rm = TRUE)
eggs[, n_ea  := n_eggs / mean]
eggs[, n_ea  := adlab(n_ea, "Eggs per month per estimated n of poultry owned")]

# 🚩 FLAG ASSUMPTION: 45 eggs/hen/year from @MacLeod.2013 p.105.
# Tanzania-specific laying rates may differ. Flag for sensitivity analysis.
eggs[, n_est := n_eggs / 45]
eggs[, n_est := adlab(n_est, "Est number of poultry required")]

excl_eggs <- eggs[, excl := fcase(
  sold > produced, "Implausible",
  n_est > mean,    "Insufficient animals"
)]
excl_eggs <- excl_eggs %>% select(y4_hhid, item = productid, excl)
write.csv(excl_eggs,
          here::here("data", "processed", "clean", "excl_eggs.csv"),
          row.names = FALSE)

# Feed requirements for egg production
ef <- eggs[, .(y4_hhid, type, productid, produced, sold, N_eggs, length)]
ef <- f[ef,      on = c("type", "y4_hhid")]
ef <- chicken[ef, on = c("feed1", "type")]

mass_eggs <- upData(ef,
  # 🚩 FLAG ASSUMPTION: Feed conversion ratio 2.3 kg DM / kg eggs from @Alexander.2016.
  # Not survey-derived. Review with domain expert before stage 3.
  need    = produced * 2.3,
  feed    = need * feed,
  grazed  = need * grazed,
  missing = produced - sold,
  consumed = 0,  # placeholder — egg consumption imputation in stage 3
  labels = .q(
    need   = "Feed requirements in DM",
    feed   = "Quantity of feed consumed in DM",
    grazed = "Quantity grazed/scavenged in DM"
  ),
  drop = .q(feed1, need, N_eggs)
)

# 🚩 FLAG ASSUMPTION: Egg consumption (missing - sold) allocated via recall data.
# This requires clean/recall.rds (cross-section dependency) and household size data
# (consumptionNPS4.dta — not yet in 01_load_raw.R — add before running this section).
# Full egg consumption allocation logic is in archive/04_Animal_products.Rmd lines 565–671.
# Decision required before stage 3: move allocation here or to a dedicated impute/ script.

saveRDS(mass_eggs, here::here("data", "processed", "clean", "mass_eggs.rds"), compress = TRUE)

message("clean/animal_products.R: animal product outputs saved.")
