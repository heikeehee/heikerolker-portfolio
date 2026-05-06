## ----set-up--------------------------------------------------------------------------------------------------
# load packages
library(tidyverse)
library(data.table)
library(Hmisc)
library(haven)
library(readxl)
library(naniar)
library(here)


## ----functions-----------------------------------------------------------------------------------------------
# calculations
sm <- function(x) sum(x, na.rm = TRUE)
rd <- function(df) df %>% dplyr::mutate_if(is.numeric, round, 1)
md <- function(x) median(x, na.rm=TRUE)
mn <- function(x) mean(x, na.rm=TRUE)

t<-1000

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

clean_up <- function(df){
  df %>%
    setDT() %>% 
    as_factor() %>%
    mutate(across(where(is.factor), tolower))%>% 
    # mutate_all(na_if,"") %>%  # does not work on all dataframes
    mutate_if(is.character, ~na_if(., '')) %>% 
    # select(!starts_with("ag")) %>%
    # select(!starts_with("lf")) %>%
    # select(!starts_with("hh_")) %>%
    select(-occ)
}


## ----read in-------------------------------------------------------------------------------------------------
# adulteq given by LSMS
consumptionNPS4 <- read_dta("2_data/files/consumptionNPS4.dta")

# household identifiers for location and recall month -> written from c3a
# hh_ids <- read_csv("2_data/files/hh_ids.csv")

# hh list with previous exclusions -> written from c3a
excl_3a <- read_csv("2_data/final/excl_3a.csv")

# food items and grouping - redundant.
# fooditems <- readRDS("2_data/reference/fooditems.RDS")


## ----metadata------------------------------------------------------------------------------------------------
# zones to be included in metadata
zones <- list(
  "Lakes" = c("Kagera", "Mara", "Mwanza", "Geita", "Simiyu", "Shinyanga", "Kigoma"),
  "Coastal" = c("Mjini Magharibi", "Kaskazini Pemba", "Kaskazini Unguja", "Kusini Pemba", "Kusini Unguja", "Lindi", "Mtwara", "Morogoro", "Pwani", "Dar Es Salaam", "Mjini/Magharibi Unguja"),
  "Central" = c("Manyara", "Dodoma", "Singida", "Tabora"),
  "Northern Highlands" = c("Arusha", "Kilimanjaro", "Tanga"),
  "Southern Highlands" = c("Iringa", "Njombe", "Ruvuma", "Katavi", "Rukwa", "Mbeya"))

zones <- data.frame(region = unlist(zones), zone = rep(names(zones), lengths(zones)))
zones <- setDT(zones)

# household identification
hh_sec_a <- read_dta("2_data/files/hh_sec_a.dta")

hhA <- hh_sec_a %>%
  select(y4_hhid, region = hh_a01_2, intmonth = hh_a18_2) %>%  # at this point all that's needed, add more as required and save if necessary
  mutate(region = str_to_title(as_factor(region))) %>%
  left_join(zones, by = "region") %>% 
  mutate(
    intmonth = ifelse(y4_hhid == "3662-001", 11, intmonth),
    intmonth = ifelse(y4_hhid == "4211-001", 11, intmonth)
  )

# general household info
write_csv(hhA, "2_data/files/hhA.csv")

# miss_var_summary(hhA)


## ----metadata new, eval=FALSE--------------------------------------------------------------------------------
# # zones to be included in metadata
# northern_highlands <- c(
#   "Meru", "Arusha mjini", "Karatu", "Arusha", "Longido", "Monduli", "Ngorongoro",
#   "Siha", "Hai", "Moshi", "Moshi manispaa", "Rombo", "Same", "Mwanga", "Lushoto"
# )
# lake_zone <- c(
#   "Geita", "Mbogwe", "Chato", "Ukerewe", "Magu", "Nyamagana manispaa", "Kwimba", "Sengerema", "Ilemela manispaa", "Misungwi",
#   "Karagwe", "Bukoba", "Muleba", "Biharamulo", "Ngara", "Missenyi", "Kyerwa",
#   "Tarime", "Serengeti", "Bunda", "Rorya", "Butiama", "Musoma", "Musoma manispaa", "Busega",
#   # own
#   "Bukoba manispaa"
# )
# southern_highlands <- c(
#   "Iringa", "Mufindi", "Iringa manispaa", "Kilolo", "Njombe", "Njombe mji", "Wang'ing'ombe", "Ludewa", "Makambako mji",
#   "Mbeya", "Kyela", "Rungwe", "Mbozi", "Mbarali", "Mbeya jiji", "Momba", "Ileje", "Sumbawanga", "Sumbawanga manispaa", "Nkasi", "Kalambo", "Tunduru", "Mbinga", "Songea", "Songea manispaa", "Nyasa", "Namtumbo",
#   # own
#   "Mafinga mji"
# )
# central_semiarid <- c(
#   "Kondoa", "Kongwa", "Dodoma mjini", "Chemba", "Mpwapwa", "Chamwino", "Bahi", "Singida", "Singida mjini", "Ikungi", "Manyoni", "Mkalama", "Iramba", "Itigi", "Tabora manispaa", "Nzega", "Igunga", "Uyui", "Urambo", "Sikonge", "Kaliua",
#   # own assessment
#   "Shinyanga manispaa", "Kishapu", "Sinyanga", "Kahama", "Kishapu", "Sinyanga", "Kahama mji",
#   "Bariadi", "Itilima", "Meatu", "Maswa", "Bariadi"
# )
# coastal <- c(
#   "Kinondoni", "Ilala", "Temeke", "Bagamoyo", "Kibaha", "Kisarawe", "Rufiji", "Mkuranga", "Kibaha mji",
#   "Tanga", "Korogwe", "Muheza", "Handeni", "Pangani", "Kilindi", "Lindi", "Kilwa", "Liwale", "Ruangwa", "Lindi manispaa",
#   "Mtwara vijijini", "Mtwara manispaa", "Masasi", "Masasi mji", "Newala", "Tandahimba", "Nanyumbu", "Nachingwea"
# )
# western <- c(
#   "Mpanda mji", "Mpanda", "Mlele", "Kasulu", "Kasulu mji", "Kigoma", "Kigoma manispaa", "Uvinza", "Buhigwe", "Kakonko", "Kibondo", "Bukombe", "Nyang'hwale"
# )
# alluvial <- c(
#   "Kilosa", "Morogoro", "Morogoro manispaa", "Ulanga", "Mvomero", "Gairo", "Kilombero", "Kiteto", "Hanang", "Mbulu", "Chunya",
#   #own
#   "Babati", "Babati mji", "Simanjiro"
# )
# zanzibar <- c(
#   "Wete", "Micheweni", "Kaskazini a", "Kaskazini b", "Chake chake", "Mkoani", "Kati", "Kusini", "Magharibi", "Mjini"
# )
# 
# # Combine into a data frame
# zones <- data.frame(
#   district = c(
#     northern_highlands, lake_zone, southern_highlands, central_semiarid, coastal, western, alluvial, zanzibar
#   ),
#   zone = c(
#     rep("Highlands", length(northern_highlands)), # combined with southern
#     rep("Lake", length(lake_zone)),
#     rep("Highlands", length(southern_highlands)),
#     rep("Central", length(central_semiarid)),
#     rep("Coastal", length(coastal)),
#     rep("Western", length(western)),
#     rep("Alluvial", length(alluvial)),
#     rep("Coastal", length(zanzibar)) # combine with coastal
#   ),
#   stringsAsFactors = FALSE
# )
# zones <- zones %>%
#   mutate(district = str_to_sentence(district))
# 
# # household identification
# hh_sec_a <- read_dta("2_data/files/hh_sec_a.dta")
# 
# hhA <- hh_sec_a %>%
#   select(y4_hhid, region = hh_a01_2, district = hh_a02_2, intmonth = hh_a18_2) %>%  # at this point all that's needed, add more as required and save if necessary
#   mutate(district = str_to_sentence(as_factor(district))) %>%
#   left_join(zones, by = "district") %>%
#   mutate(
#     intmonth = ifelse(y4_hhid == "3662-001", 11, intmonth),
#     intmonth = ifelse(y4_hhid == "4211-001", 11, intmonth)
#   )
# 
# # general household info
# write_csv(hhA, "2_data/files/hhA.csv")
# 
# # miss_var_summary(hhA)


## ----MAIN food consumption - load data, eval=FALSE-----------------------------------------------------------
# # food frequency in past 7 days
# hh_sec_j3 <- read_dta("2_data/files/hh_sec_j3.dta")
# 
# # food consumed by others in the household
# hh_sec_j4 <- read_dta("2_data/files/hh_sec_j4.dta")


## ----hk recall-----------------------------------------------------------------------------------------------
# main food consumption data
hh_sec_j1 <- read_dta("2_data/files/hh_sec_j1.dta")

recall <- clean_up(hh_sec_j1) %>%
  zap_labels()

lapply(hh_sec_j1, attr, "label")
contents(recall)
head(recall)


## ----shape recall--------------------------------------------------------------------------------------------
recall <- upData(recall,
                 rename =.q(
                   hh_j01 = consumed,
                   hh_j02_2 = quantity,
                   hh_j03_2 = purchases,
                   hh_j04 = value,
                   hh_j04_1 = source,
                   hh_j05_2 = production,
                   hh_j06_2 = gifts,

                   hh_j02_1 = unit,
                   hh_j03_1 = u_bought,
                   hh_j05_1 = u_produced,
                   hh_j06_1 = u_gifts
                 ),

                 # replace NA with true 0
                 quantity = ifelse(consumed == "no", 0, quantity),
                 purchases = ifelse(consumed == "no", 0, purchases),
                 production = ifelse(consumed == "no", 0, production),
                 gifts = ifelse(consumed == "no", 0, gifts),

                 # unit = as.factor(hh_j02_1),
                 # u_bought = as.factor(hh_j03_1),
                 # u_produced = as.factor(hh_j05_1),
                 # u_gifts = as.factor(hh_j06_1),
                 #drop = .q(
                   #hh_j02_1, hh_j03_1, hh_j05_1, hh_j06_1),
                 labels = .q(
                   consumed = 'Item consumed',
                   quantity = 'Quantity of item consumed in the household',
                   purchases = 'Quantity of item purchased',
                   value = 'Expenditure on item from purchase',
                   source = 'Source of purchase',
                   production = 'Quantity of item from own production',
                   gifts = 'Quantity of item from gifts',
                   unit = 'Unit of consumption'
                 ))

contents(recall)

# save to 3a for estimating egg consumption
# saveRDS(here("..", "03a_simpleMFA", "2_data/processed/recall.RDS"))


## ----conversions---------------------------------------------------------------------------------------------
## Conversion factors-----

# yoghurt, plain, whole milk = 1.04
# cheddar cheese = 0.48
# cream heavy/light, fluid = 1.01
# cheese cream = 0.98
# buns, cakes & biscuits: can be anything between 5g and 600g
# bread: estimate
# coconut: https://www.howmuchisin.com/produce_converters/coconut
# can of soda contains 355ml
# sweet potato; use yam: https://www.inchcalculator.com/convert/liter-to-kilogram/
# and vegetables onions = 0.22; carrots 0.54 --> middle of 0.3
# oil, cooking and salad, ENOVA, 80% diglycerides

items <- data.frame(
  unit = c(
    "litre", "pieces", "litre", "litre", "litre",
    "litre", "litre", "litre", "litre", "pieces",
    "pieces", "pieces", "millilitre", "millilitre", "millilitre",
    "millilitre", "millilitre","millilitre", "millilitre","millilitre",
    "millilitre", "millilitre", "pieces", "litre", "litre",
    "litre"

  ),
  itemcode = c(
    "fresh milk", "eggs", "milk products (like cream, cheese, yoghurt etc)", "cooking oil", "bottled/canned soft drinks (soda, juice, water)",
    "bottled beer", "local brews", "honey, syrups, jams, marmalade, jellies, canned fruits", "buns, cakes and biscuits","bread",
    "coconuts (mature/immature)", "sweets", "cooking oil","fresh milk", "milk products (like cream, cheese, yoghurt etc)",
    "bottled/canned soft drinks (soda, juice, water)", "honey, syrups, jams, marmalade, jellies, canned fruits", "wine and spirits", "bottled beer", "local brews",
    "prepared tea, coffee", "peas, beans, lentils and other pulses", "bottled/canned soft drinks (soda, juice, water)", "butter, margarine, ghee and other fat products", "sweet potatoes",
    "canned, dried and wild vegetables"
  ),
  conv = c(
    1.08, 0.04126, 1.01, 0.9, 1, # egg weight based on FAO report
    1, 1, 1.43, 0.02, 0.5,
    0.8, 0.05, 0.001, 0.001, 0.001,
    0.001, 0.001, 0.001, 0.001, 0.001,
    0.001, 0.001, 0.355, 0.959, 0.66,
    0.3
  )
)

items <- items %>%
  mutate(
    unit = as.factor(unit)
  ) %>%
  setDT()



## ----rematch with dt-----------------------------------------------------------------------------------------

## total consumption
irec <- items[recall, on = c("itemcode", "unit")]

irec[, conv := fcase(
  unit == "litre", conv,
  unit == "pieces", conv,
  unit == "millilitre", conv,
  unit == "kilograms", 1,
  unit == "grams", 0.001,
  is.na(unit), 0)]

# convert to kg
irec[, quantity_new := quantity*conv]

# drop not needed & rename for next
irec[, conv:= NULL]
irec <- rename(irec, c(u_cons = unit, unit = u_bought))

irec[, unit := as.character(unit)]

## purchases
irec <- items[irec, on = c("itemcode", "unit")]

irec[, conv := fcase(
  unit == "litre", conv,
  unit == "pieces", conv,
  unit == "millilitre", conv,
  unit == "kilograms", 1,
  unit == "grams", 0.001,
  is.na(unit), 0)]

# convert to kg [change here]
irec[, purchases_new := purchases*conv]

# drop not needed & rename for next
irec[, conv:= NULL]
irec <- rename(irec, .q(u_bought = unit, unit = u_produced))

irec[, unit := as.character(unit)]

## own production
irec <- items[irec, on = c("itemcode", "unit")]

irec[, conv := fcase(
  unit == "litre", conv,
  unit == "pieces", conv,
  unit == "millilitre", conv,
  unit == "kilograms", 1,
  unit == "grams", 0.001,
  is.na(unit), 0)]

# convert to kg [change here]
irec[, production_new := production*conv]

# drop not needed & rename for next
irec[, conv:= NULL]
irec <- rename(irec, .q(u_produced = unit, unit = u_gifts))

irec[, unit := as.character(unit)]

## gifts

irec <- items[irec, on = c("itemcode", "unit")]

irec[, conv := fcase(
  unit == "litre", conv,
  unit == "pieces", conv,
  unit == "millilitre", conv,
  unit == "kilograms", 1,
  unit == "grams", 0.001,
  is.na(unit), 0)]

# convert to kg [change here]
irec[, gifts_new := gifts*conv]

# drop not needed & rename for next
irec[, conv:= NULL]
rename(irec, .q(u_gifts = unit))

# purpose?
saveRDS(irec, file = "2_data/files/recall_converted.RDS", compress = TRUE)


## ------------------------------------------------------------------------------------------------------------
# recall data
recall <- readRDS("2_data/files/recall_converted.RDS")

# select _new variables only (cleaned in data_preparation for 3a)
# initial conversion to metric took place here
rec7d <- recall %>% select(y4_hhid, itemcode, contains("_new"))

# select _new variables, i.e. all kg info, rename for simplicity and speed
rec7d <- upData(rec7d,
              rename= .q(
                quantity_new = quant, # all in kg
                production_new = produced,
                purchases_new = purch,
                gifts_new = gifts
              ))

rec7d <- clear.labels(rec7d)


## ------------------------------------------------------------------------------------------------------------
# load fct info: here LSHTM matching (add link...)
fct <- read_excel("2_data/reference/TFNC_NCT_NTPS20_v.3.0.0.xlsx") %>%
  mutate(item_desc = str_to_lower(item_desc))

rec7d_kcal <- rec7d %>%
  left_join(select(fct, itemcode = item_desc, ENERCkcal), by = "itemcode") %>% # add kcal information
  mutate(quant_kcal = quant * 10 * ENERCkcal) %>% # ENERCkcal per 100 g, quant is 1 kg
  select(y4_hhid, itemcode, quant, quant_kcal) %>%
  group_by(y4_hhid) %>% # collapse to household for total consumption
  summarise(
    quant_kcal = sum(quant_kcal, na.rm = TRUE) # 11 quant_kcal truly missing (quant != 0 ) marginal effect, hence ignore
  )


## ------------------------------------------------------------------------------------------------------------
# load aFMe summaries
aFMe_summaries <- read_csv("2_data/final/aFMe_summaries.csv")

rec7d_kcal_afme <- rec7d_kcal %>%
  left_join(select(aFMe_summaries, y4_hhid, amehh, afehh), by = "y4_hhid") %>%
  filter(!is.na(amehh)) %>% # 6 households missing, don't seem listed in detail
  mutate(
    ame_kcald = quant_kcal/7/amehh,
    afe_kcald = quant_kcal/7/afehh
  )

# determine number of excluded households for ame & afe
rec7d_kcal_afme %>% filter(ame_kcald < 500 | ame_kcald > 5000) # 383 households
rec7d_kcal_afme %>% filter(afe_kcald < 500 | afe_kcald > 5000) # 259 households


## ----exclusions recall, eval=FALSE---------------------------------------------------------------------------
# # exclusions based on household
# # 1) exclude unrealistic daily kcal consumption
# rec7d_excl1 <- rec7d_kcal_afme %>%
#   mutate(
#     excl = ifelse(afe_kcald < 500 | ame_kcald > 5000, "Consumption unrealistic", NA),
#     status = ifelse(!is.na(excl), "excluded", NA)
#   ) %>%
#   setDT() %>%
#   select(y4_hhid, excl)
# 
# # 2) exclude no consumption
# excl_cons <- rec7d %>%
#   group_by(y4_hhid) %>%
#   summarise(
#     cons = sm(quant)
#   ) %>%
#   filter(cons == 0) %>%
#   add_column(
#     excl = "No consumption"
#   ) %>%
#   select(!cons)
# 
# # exclusions based on items list
# # 3) 30% unaccounted
# # 4) any 20% above
# rec7d_excl <- rec7d %>%
#   mutate(
#     smd = purch+produced+gifts,
#     quant12 = quant*1.2,
#     excl = ifelse(smd > quant * 1.3, "Consumption insufficient", NA),
#     excl = ifelse(smd < quant * 0.7, "Consumption unaccounted", excl),
#     excl = ifelse(purch > quant12 | produced > quant12 | gifts > quant12, "Data inconsistent", excl)) %>%
#   setDT() %>%
#   select(y4_hhid, excl)
# 
# # list of exclusions based on recall only
# excl_list_recall <- bind_rows(excl_cons, rec7d_excl, rec7d_excl1)
# excl_list_recall <- excl_list_recall %>%
#   mutate(excl = ifelse(y4_hhid == "3800-001" | y4_hhid == "4786-001", "Unclear why", excl)) # no AFE, cannot find error
# 
# write_csv(excl_list_recall, "2_data/files/excl_list_recall.csv")
# 
# # create list of status
# excl1 <- excl_list_recall %>%
#   filter(!is.na(excl)) %>%
#   select(y4_hhid) %>%
#   unique() %>%
#   add_column(
#     status = "excluded"
#   ) %>% setDT()
# 
# allhhids <- hh_sec_a %>% select(y4_hhid) %>% unique() %>% setDT()
# 
# # remove excluded from list of hhs
# incl <- allhhids[!excl1, on = .(y4_hhid)]
# incl[, status := "included"]
# 
# exclA <- bind_rows(excl1, incl)
# 
# # recall exclusions
# write_csv(exclA, "2_data/appendix/excl_recall.csv")
# 
# # read exclusions from 3a
# excl_3a <- read_csv("2_data/final/excl_3a.csv")
# 
# # join exclusions ag only
# ag_ids <- read_csv("2_data/final/ag_ids.csv") %>% # lists all households
#   filter(!is.na(interview_date))
# 
# # list of agricultural households and their inclusion status
# excl_3b <- exclA %>%
#   filter(status == "excluded") %>%
#  # reduce to ag ids only
#   inner_join(select(ag_ids, y4_hhid), by = "y4_hhid") %>%
#   select(y4_hhid) %>%
#   bind_rows(excl_3a) %>%
#   unique() %>%
#   mutate(
#     status = "excluded"
#   ) %>%
#   full_join(select(ag_ids, y4_hhid), by = "y4_hhid") %>%
#   mutate(
#     status = ifelse(is.na(status), "included", status)
#   ) %>%
#   select(y4_hhid, status) %>%
#   unique()
# 
# # agricultural zones: https://research.csiro.au/livegaps/findings/livestock-production/dairy-production-in-tanzania/
# zones <- data.table(
#   zone = c(rep("Lakes", 7), rep("Coastal", 10), rep("Central", 4), rep("Northern Highlands",3), rep("Southern Highlands", 6)),
#   region = c("Kagera", "Mara", "Mwanza", "Geita", "Simiyu", "Shinyanga", "Kigoma",
#              "Mjini Magharibi", "Kaskazini Pemba", "Kaskazini Unguja", "Kusini Pemba", "Kusini Unguja", "Lindi", "Mtwara", "Morogoro", "Pwani", "Dar Es Salaam",
#              "Manyara", "Dodoma", "Singida", "Tabora",
#              "Arusha", "Kilimanjaro", "Tanga",
#              "Iringa", "Njombe", "Ruvuma", "Katavi", "Rukwa", "Mbeya"
#              ))
# 
# zones <- zones %>%
#   mutate(region = tolower(region))
# 
# ag_ids_zone <- ag_ids %>%
#   select(y4_hhid, region) %>%
#   left_join(zones, by = "region") %>%
#   right_join(excl_3b, by = "y4_hhid")
# 
# excl_3b <- ag_ids_zone %>%
#   select(y4_hhid, status, zone)
# 
# # combined exclusions
# write_csv(excl_3b, "2_data/final/excl_3b.csv")
# write_csv(excl_3b, "2_data/results/excl_3b.csv")


## ----exclusions recall new-----------------------------------------------------------------------------------
rec7d_excl1 <- rec7d_kcal_afme %>%
  mutate(
    excl = ifelse(afe_kcald < 500 | ame_kcald > 5000, "Consumption unrealistic", NA),
    status = ifelse(!is.na(excl), "excluded", NA)
  ) %>%
  setDT() %>% 
  select(y4_hhid, excl)

# 2) exclude no consumption
excl_cons <- rec7d %>% 
  group_by(y4_hhid) %>% 
  summarise(
    cons = sm(quant)
  ) %>% 
  filter(cons == 0) %>% 
  add_column(
    excl = "No consumption"
  ) %>% 
  select(!cons)

# exclusions based on items list
# 3) 30% unaccounted
# 4) any 20% above
rec7d_excl <- rec7d %>%
  mutate(
    smd = purch+produced+gifts,
    quant12 = quant*1.2,
    excl = ifelse(smd > quant * 1.3, "Consumption insufficient", NA),
    excl = ifelse(smd < quant * 0.7, "Consumption unaccounted", excl),
    excl = ifelse(purch > quant12 | produced > quant12 | gifts > quant12, "Data inconsistent", excl)) %>%
  setDT() %>% 
  select(y4_hhid, excl)

# list of exclusions based on recall only
excl_list_recall <- bind_rows(excl_cons, rec7d_excl, rec7d_excl1)
excl_list_recall <- excl_list_recall %>% 
  mutate(excl = ifelse(y4_hhid == "3800-001" | y4_hhid == "4786-001", "Unclear why", excl)) # no AFE, cannot find error

write_csv(excl_list_recall, "2_data/files/excl_list_recall.csv")

# create list of status
excl1 <- excl_list_recall %>%
  filter(!is.na(excl)) %>%
  select(y4_hhid) %>%
  unique() %>%
  add_column(
    status = "excluded"
  ) %>% setDT()

allhhids <- hh_sec_a %>% select(y4_hhid) %>% unique() %>% setDT()

# remove excluded from list of hhs
incl <- allhhids[!excl1, on = .(y4_hhid)]
incl[, status := "included"]

exclA <- bind_rows(excl1, incl)

# recall exclusions
write_csv(exclA, "2_data/appendix/excl_recall.csv") # naming could be better but ok

# read exclusions from 3a
# excl_3a <- read_csv("2_data/final/excl_3a.csv")
excl_3a <- read_csv("2_data/final/hhs_3a.csv")

excl_3b <- exclA %>% 
  rename(status_recall = status) %>% 
  full_join(excl_3a, by = "y4_hhid") 

# add zones
full_overview_hh4 <- hhA %>%
  select(y4_hhid, region, zone, month = intmonth) %>%
  full_join(excl_3b, by = "y4_hhid") %>% 
  mutate(final_status4 = ifelse(status == "excluded" | status_recall == "excluded", "excluded", NA))

fwrite(full_overview_hh4, "2_data/results/full_overview_hh4.csv")

# join exclusions ag only - below does not represent ag hh, but crop producers
# ag_ids <- read_csv("2_data/final/ag_ids.csv") %>% # lists all households
#   filter(!is.na(interview_date))

# list of agricultural households and their inclusion status
# excl_3b <- exclA %>%
#   filter(status == "excluded") %>%
#  # reduce to ag ids only
#   inner_join(select(ag_ids, y4_hhid), by = "y4_hhid") %>%
#   select(y4_hhid) %>%
#   bind_rows(excl_3a) %>%
#   unique() %>%
#   mutate(
#     status = "excluded"
#   ) %>%
#   full_join(select(ag_ids, y4_hhid), by = "y4_hhid") %>%
#   mutate(
#     status = ifelse(is.na(status), "included", status)
#   ) %>%
#   select(y4_hhid, status) %>%
#   unique()
# 
# 
# 
# excl_3b <- ag_ids_zone %>%
#   select(y4_hhid, status, zone)

# combined exclusions
write_csv(excl_3b, "2_data/final/excl_3b.csv")
write_csv(excl_3b, "2_data/results/excl_3b.csv")





## ------------------------------------------------------------------------------------------------------------
# convert to monthly afe
recmo <- rec7d %>%
  left_join(select(aFMe_summaries, y4_hhid, afehh), by = "y4_hhid") %>%
  mutate(
    across(quant:gifts, ~.x / afehh, # or any other if so required
           .names = "{.col}_afe"), # per afe consumption from various sources in kg
    across(quant_afe:gifts_afe, ~.x * 4.3,
           .names = "{.col}_mo")) # extrapolated monthly per afe consumption from various sources in kg


## ------------------------------------------------------------------------------------------------------------
# 3) add shortnames
# 4) add zones & months
shortnames <- read_excel("2_data/reference/shortnames.xlsx")

recmo1 <- recmo %>%
  left_join(shortnames, by = "itemcode") %>%
  left_join(select(hhA, y4_hhid, zone, intmonth), by = "y4_hhid")  %>% 
  dplyr::rename(month = intmonth)
  # two households with months missing! interview date recorded in ag_ids -> fixed in hhA

fwrite(recmo1, "2_data/results/recall_details.csv")


## ----fish cleaning-------------------------------------------------------------------------------------------
lf_sec_09 <- read_dta("2_data/files/lf_sec_09.dta") %>% 
    setDT() %>% 
    as_factor() %>%
    mutate(across(where(is.factor), tolower))%>% 
    mutate_if(is.character, ~na_if(., '')) %>% 
    select(-occ)

fish_labour <- lf_sec_09 %>% 
  select(y4_hhid, id = indidy3, wks_fished = lf09_02_1, dys_fished = lf09_02_2, wks_processed = lf09_03_1, dys_processed = lf09_03_2, wks_traded = lf09_04_1, dys_traded = lf09_04_2) %>% 
  filter(!is.na(wks_fished)) %>% 
  mutate(
    fisher = ifelse(wks_fished > 0, 1, 0),
    processor = ifelse(wks_processed > 0, 1, 0),
    trader = ifelse(wks_traded > 0, 1, 0)
  ) # probably not necessary

lf_sec_12 <- read_dta("2_data/files/lf_sec_12.dta") %>% 
    setDT() %>% 
    as_factor() %>%
    mutate(across(where(is.factor), tolower))%>% 
    mutate_if(is.character, ~na_if(., '')) %>% 
    select(-occ)

fishes <- lf_sec_12 %>% 
  select(y4_hhid, species = lf12_02_2, tot.quantity = lf12_05_1, tot.unit = lf12_05_2, # total quantities fished
        wks_fished = lf12_07, 
        quantity = lf12_08_1, unit = lf12_08_2, # per week
        quant_preserved1 = lf12_10_1, unit_preserved1 = lf12_10_2, mtd_preserved1 = lf12_10_3, quant_preserved2 = lf12_10_4, unit_preserved2 = lf12_10_5, mtd_preserved2 = lf12_10_6,
         wks_sales = lf12_11, sold1 = lf12_12_1, sold.unit1 = lf12_12_2, sold.type1 = lf12_12_3, 
        sold2 = lf12_12_5, sold.unit2 = lf12_12_6, sold.type2 = lf12_12_7,
        consumed1 = lf12_13_1, consumed.unit1 = lf12_13_2, consumed.type1 = lf12_13_3, consumed2 = lf12_13_4, consumed.unit2 = lf12_13_5, consumed.type2 = lf12_13_6) %>% 
  mutate(tot.quantity = ifelse(is.na(tot.quantity), 0, tot.quantity), # important to keep empty for cross-referencing
         tot.unit = ifelse(tot.unit == "kipande", "piece", tot.unit)) 

saveRDS(fishes, "2_data/final/fishes.RDS", compress = T)
  
# lapply(lf_sec_09, attr, "label") 
# lapply(lf_sec_12, attr, "label") 


## ----fish consumption----------------------------------------------------------------------------------------
fish_consumption <- fishes %>% 
  mutate(
    consumed1 = ifelse(is.na(consumed1) & tot.quantity > 0, 0, consumed1), 
    consumed2 = ifelse(is.na(consumed2) & tot.quantity > 0, 0, consumed2),
    consumed = consumed1 + consumed2,
    tot.consumed = consumed * wks_fished
  ) %>% 
  mutate(
    item1 = ifelse(consumed.type1 == "fresh" | consumed.type2 == "fresh", "fresh fish", NA),
    item2 = ifelse((consumed.type1 != "fresh" & !is.na(consumed.type1)) | (consumed.type2 != "fresh" & !is.na(consumed.type2)), "processed fish", NA),
    unit.cons = ifelse(consumed.unit1 == "kilogram" & (consumed.unit2 == "kilogram" | is.na(consumed.unit2)), "kilogram", "other")) %>% 
    select(y4_hhid, tot.quantity, tot.unit, tot.consumed, unit.cons, item1, item2) 

saveRDS(fish_consumption, "2_data/final/fish_consumption.RDS", compress = T)

# fish_consumption %>% filter(tot.quantity<tot.consumed) %>% View() # not the same unit... therefore not an exclusion factor, impossible to convert to kg


## ------------------------------------------------------------------------------------------------------------
ag_sec_01 <- read_csv("2_data/files/ag_sec_01.csv") %>% 
  filter(ag01_04 == "X") %>% 
  select(y4_hhid, indidy4) %>% 
  add_column(section = "agriculture")

lf_sec_01 <- read_csv("2_data/files/lf_sec_01.csv") %>% 
  filter(lf01_04 == "X") %>% 
  select(y4_hhid, indidy4) %>% 
  add_column(section = "livestock")

hh_sec_b <- read_dta("2_data/files/hh_sec_b copy.dta") %>% 
  mutate(relationship = str_to_lower(as_factor(hh_b05)),
         sex = str_to_lower(as_factor(hh_b02))) %>% 
  select(y4_hhid, indidy4, relationship, sex)

respondents <- ag_sec_01 %>% 
  bind_rows(lf_sec_01) %>% 
  left_join(hh_sec_b, by = c("y4_hhid", "indidy4")) %>% 
  # remove excluded households
  left_join(excl_3b, by = "y4_hhid")

saveRDS(respondents, "2_data/final/respondents.RDS")



## ----exclusions, eval=FALSE----------------------------------------------------------------------------------
# exclusions <- copy(recall_mo)
# setDT(exclusions)
# # exclude top 2% for item in zone
# top2 <- function(x) quantile(x, probs = .98, na.rm=TRUE) # function to calculate top 2
# 
# # kcal exclusions
# cals <- exclusions %>% group_by(y4_hhid) %>%
#   summarise(tot_kcal_pd = sm(kcal_pd)) %>% # total kcal intake for all products in household
#   setDT()
# 
# cals[, top := top2(tot_kcal_pd)] # top 2% of per person daily kcal consumption
# 
# # exclude on kcal consumption
# # @Mekonnen.2021 <500 | >5000
# # exclude
# cals[tot_kcal_pd<500 | tot_kcal_pd>5000] # n=395
# cals[tot_kcal_pd>top] # n=68
# 
# cals[tot_kcal_pd==0] # n=68
# 
# exclusions[smd > quant * 1.3] # n=60
# exclusions[smd < quant * 0.7] # n=75
# 
# exclusions %>%filter_at(vars(purch:gifts), any_vars(. > quant*1.2))  # n=49
# 
# # code exclusions
# exclusions[, excl := NA]
# exclusions[, excl := fcase(
#     smd > quant * 1.3, "Consumption insufficient",
#     smd < quant * 0.7, "Consumption unaccounted")]
# ex1 <- exclusions[,.(y4_hhid, itemcode, excl)]
# 
# ex2 <- exclusions %>%
#   filter(is.na(excl)) %>%
#   filter_at(vars(purch:gifts), any_vars(. > quant*1.2)) %>%   # n=49
#   mutate(excl = "Data inconsistent") %>%
#   select(y4_hhid, itemcode, excl)
# 
# # merge exclusions
# # remove ex2 from ex1
# ex1 <- ex1[!ex2, on = .(y4_hhid, itemcode)]
# exclusions <- rbind(ex1, ex2)
# 
# cals[, exclude := fcase(
#   tot_kcal_pd<500 | tot_kcal_pd>5000, "kcal unrealistic",
#   tot_kcal_pd == 0, "No consumption")]
# 
# ex3 <- cals[,.(y4_hhid, exclude)]
# 
# exclusions <- cals[exclusions, on = .(y4_hhid)]
# exclusions[, excl := ifelse(is.na(excl) & !is.na(exclude), exclude, excl)]
# 
# # reduce vars with reason for obs
# exclusions <- exclusions[,.(y4_hhid, itemcode, excl)]
# 
# # list of excluded households
# ex_hhs <- exclusions %>%
#   mutate(excluded = ifelse(!is.na(excl),1,0)) %>%
#   group_by(y4_hhid) %>%
#   summarise(sum = sum(excluded)) %>%
#   mutate(statushh = ifelse(sum >0, "excluded", "included")) %>%
#   mutate(statushh = ifelse( # --> make sure ex_no_region are excluded: 8277-001; 4211-001 should be included but no metadata
#     y4_hhid == "2164-001"| y4_hhid == "2182-001" | y4_hhid == "2887-001" | y4_hhid == "3662-001" | y4_hhid == "4102-001" |
#     y4_hhid == "4211-001"| y4_hhid == "4554-001" | y4_hhid == "8277-001", "excluded", statushh)) %>% # exclude hhs from ex_no_region
#   setDT()
# 
# ex_hhs[statushh == "included"]


## ----recall, eval=FALSE--------------------------------------------------------------------------------------
# # add food groups & identifiers / replace with file that contains all info
# foods <- fooditems %>% select(itemcode, shortnames) %>% unique() # recall items match to multiple ag items
# 
# rec <- rec %>%
#   left_join(foods, by = "itemcode") %>%  # add short names for wide
#   mutate(y4_hhid = as.character(y4_hhid)) %>%
#   # select which ame to use
#   # left_join(select(household, y4_hhid, ame = ame_coates, hh_consumers, hhsize, region, zone, month = intmonth), by ="y4_hhid") # select ame if multiple
#   left_join(aMFe_summaries, by = "y4_hhid")


## ----recall identifiers & dems, eval=FALSE-------------------------------------------------------------------
# # compute per capita consumption
# recall_mo <- rec_ken %>% # KENYA! alternatively: rec_tza
#   mutate(
#     across(quant:gifts, ~.x / hh_ame, # or hh_fme if desired
#            .names = "pp_{.col}"),
#     # monthly consumption of each product
#     across(pp_quant:pp_gifts, ~.x * 4.3,
#            .names = "{.col}_mo"),
#     smd = purch+produced+gifts) %>% # sum of all sources, required for exclusion
#   relocate(smd, .after=gifts) %>%
#   mutate(kcal_pd = kcal/7/hh_ame) %>%  # per AME kcal per day derived from item
#   left_join(select(household, y4_hhid, zone, month=intmonth), by = "y4_hhid")
# 
# recall_mo <- upData(recall_mo,
#                     labels = .q(
#                       zone = "Agricultural zones",
#                       ame = "AME hces Nut package", # change if necessary
#                       excl = "Reason for exclusion",
#                       itemcode = "Food item consumed",
#                       smd = "Sum of disposition",
#                       pp_quant = "Per capita 7-day consumption",
#                       pp_purch = "Per capita 7-day AME purchased",
#                       pp_produced = "Per capita 7-day AME produced",
#                       pp_gifts = "Per capita 7-day AME received as gifts",
#                       pp_quant_mo = "Monthly extrapolated AME consumed, per cap",
#                       pp_purch_mo = "Monthly extrapolated AME purchased, per cap",
#                       pp_produced_mo = "Monthly extrapolated AME produced, per cap",
#                       pp_gifts_mo = "Monthly extrapolated AME received as gifts, per cap"
#                     ))


## ----fix food groups/matching, eval=FALSE--------------------------------------------------------------------
# short_names <- read_excel("2_data/reference/foods.xlsx", sheet = "short_names")
# setDT(short_names)
# foods <- read_excel("2_data/reference/foods.xlsx", sheet = "foods")
# setDT(foods)
# 
# fooditems <- foods[short_names, on = .(itemcode)]
# 
# fooditems <- upData(fooditems,
#                     labels = .q(
#                       itemcode = "Recall itemcode",
#                       shortnames = "Shortnames for widedata",
#                       product = "Corresponding item from food production",
#                       type = "Food group from food production",
#                       group_adj = "Food group based on TZA food composition table"
#                     ),
#                     drop = .q(comment))
# 
# saveRDS(fooditems, "2_data/reference/fooditems.RDS", compress = T)


## ----Kenya FCT kcal, eval=FALSE------------------------------------------------------------------------------
# # match file provided by LSHTM MAPS project - rough!
# maps_match <- read_excel("2_data/reference/TFNC_NCT_NTPS20_v.2.0.0.xlsx")
# 
# rec <- clear.labels(rec)
# rec_ken <- maps_match %>%
#   mutate(itemcode = tolower(item_desc)) %>%
#   select(itemcode, energy = ENERCkcal) %>%
#   right_join(rec, by = "itemcode") %>%
#   mutate(kcal = quant*10*energy) # kcal per 100g product


## ----first match, eval=FALSE---------------------------------------------------------------------------------
# # generate key for matches, does not need to be done again
# # match to TZA FCT
# # no need to run again
# if (!require("devtools")) {
#   install.packages("devtools")
# }
# devtools::install_github("TomCodd/NutritionTools")
# library(NutritionTools)
# library(dplyr)
# 
# # prep for fuzzy matcher
# macs <- select(macronutrients, ID, Item)
# surveyfoods <- rec %>% select(Item = itemcode) %>% unique()
# surveyfoods <- surveyfoods %>% mutate(ID = 1:nrow(surveyfoods)) %>% relocate(ID, .before = Item)
# 
# # use fuzzy matcher
# # Fuzzy_Matcher(df1 = surveyfoods, df2 = macs)
# 
# fuzz_match <- `fuzzy_match_outputs_2023-11-09 08:42:18.156701`
# colnames(fuzz_match) <- c("survey", "FCT", "Confidence")
# 
# # merge items back in
# matchup <- fuzz_match %>%
#   right_join(surveyfoods, by = c("survey" = "ID")) %>%
#   left_join(macs, by = c("FCT" = "ID"))
# 
# # finalise remaining matching manually -> manual match saved as excel
# write_csv(matchup, "2_data/reference/matchup.csv")


## ----TZA FCT kcal, eval=FALSE--------------------------------------------------------------------------------
# # matching based on previous chunk
# macronutrients <- read_excel("2_data/reference/macronutrients.xlsx")
# matchup <- read_excel("2_data/reference/matchup.xlsx", col_types = c("skip", "numeric", "text", "text", "text", "text", "text"))
# matchmult <- read_excel("2_data/reference/matchup.xlsx", sheet = "matchmultiple")
# 
# # add kcal to matchmult & calculate average for item
# matchmult <- matchmult %>%
#   select(!weighting) %>%
#   rename(itemcode = Item.x,
#          Item = Item.y) %>%
#   left_join(select(macronutrients, ID, group = Group, Item, ENERGY_kcal), by = c("FCT" = "ID", "Item")) %>%
#   setDT()
# 
# # calculate average and shorten
# items1 <- matchmult %>%
#   group_by(itemcode, group) %>%
#   summarise(kcal = mean(ENERGY_kcal)) %>%
#   select(itemcode, kcal, group)
# 
# # add kcal to matchup, rbin with matchmult
# items2 <- matchup %>%
#   rename(itemcode = Item.x,
#          Item = Item.y) %>%
#   filter(is.na(comment), !is.na(Item)) %>%
#   left_join(select(macronutrients, ID, Group, Item, ENERGY_kcal), by = "Item") %>%
#   select(itemcode, kcal = ENERGY_kcal, group = Group) %>%
#   setDT()
# 
# itemskcal <- items1 %>% rbind(items2) %>% unique() %>% setDT()
# 
# # add kcal to recall for exclusion step
# rec_tza <- rec %>%
#   mutate(itemcode = as.character(itemcode)) %>%
#   left_join(itemskcal, by = c("itemcode")) %>%
#   mutate(kcal = quant*10*kcal) # kcal per 100g product consumed in the household


## ----sort out: TBD!, eval=FALSE------------------------------------------------------------------------------
# food_key <- readRDS("2_data/reference/food_key.RDS")
# fooditems <- readRDS("2_data/reference/fooditems.RDS")
# foods <- readRDS("2_data/reference/foods.RDS")
# TZA_LSMS_foods <- read_excel("2_data/reference/TZA_LSMS_foods.xlsx")
# matchup.xlsx
# matchup2.xlsx
# 
# 
# foods <- itemskcal[fooditems, on=.(itemcode)] # should be foods_key
# 
# master_foodkey
# 
# saveRDS(foods, "2_data/reference/foods.RDS", compress = T)


## ----eval=FALSE----------------------------------------------------------------------------------------------
# # compute per capita consumption
# recall_mo <- rec_ken %>% # KENYA! alternatively: rec_tza
#   mutate(
#     across(quant:gifts, ~.x / hh_ame, # or hh_fme if desired
#            .names = "pp_{.col}"),
#     # monthly consumption of each product
#     across(pp_quant:pp_gifts, ~.x * 4.3,
#            .names = "{.col}_mo"),
#     smd = purch+produced+gifts) %>% # sum of all sources, required for exclusion
#   relocate(smd, .after=gifts) %>%
#   mutate(kcal_pd = kcal/7/hh_ame) %>%  # per AME kcal per day derived from item
#   left_join(select(household, y4_hhid, zone, month=intmonth), by = "y4_hhid")
# 
# recall_mo <- upData(recall_mo,
#                     labels = .q(
#                       zone = "Agricultural zones",
#                       ame = "AME hces Nut package", # change if necessary
#                       excl = "Reason for exclusion",
#                       itemcode = "Food item consumed",
#                       smd = "Sum of disposition",
#                       pp_quant = "Per capita 7-day consumption",
#                       pp_purch = "Per capita 7-day AME purchased",
#                       pp_produced = "Per capita 7-day AME produced",
#                       pp_gifts = "Per capita 7-day AME received as gifts",
#                       pp_quant_mo = "Monthly extrapolated AME consumed, per cap",
#                       pp_purch_mo = "Monthly extrapolated AME purchased, per cap",
#                       pp_produced_mo = "Monthly extrapolated AME produced, per cap",
#                       pp_gifts_mo = "Monthly extrapolated AME received as gifts, per cap"
#                     ))

