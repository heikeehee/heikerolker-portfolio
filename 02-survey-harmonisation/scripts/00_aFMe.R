## ------------------------------------------------------------------------------------------------------------
library(tidyverse)
library(readr)
library(naniar)
library(data.table)
library(haven)

sm <- function(x) sum(x, na.rm = TRUE)


## ------------------------------------------------------------------------------------------------------------
dataV <- read_csv("2_data/files/hh_sec_v.csv")

dataV <- dataV %>% 
  rename(weight = hh_v05, height = hh_v06) %>% 
  select(y4_hhid, indidy4, weight, height)

dataB <- read_csv("2_data/files/hh_sec_b.csv")

dataB <- dataB %>% 
  rename(sex = hh_b02, age = hh_b04, eat7d = hh_b07, moid = hh_b15, moabs = hh_b10) %>% 
  select(y4_hhid, indidy4, sex, age, eat7d, moid, moabs)   # eat7d (to select individual who consumed food in the HHs in the last 7 days), moid (identify biological mothers of children below 2 yrs of age), moabs (number of months absent in past 12 months)

write_csv(dataB, "2_data/files/dataB.csv")

dataVB <- left_join(dataV, dataB, by= c('y4_hhid', 'indidy4'))

options(scipen = 10, digits=3) # set up the decimal places of the calculated values

meanwh <- dataVB %>% 
  group_by(sex, age) %>% 
  summarise(meanw = mean(weight, na.rm=TRUE),
            meanh = mean(height, na.rm=TRUE))

write_csv(meanwh, '2_data/files/whbyage.csv') 
# several age/sex groups missing weight and height information -> leads ultimately to exclusion of six households
miss_var_summary(meanwh)


## ------------------------------------------------------------------------------------------------------------
dataB <- read_csv("2_data/files/dataB.csv")

dataB_lact <- dataB %>% 
  select(y4_hhid, indidy4, sex, age, moid, eat7d) %>% 
  filter(eat7d == 1) %>%     # select only women who ate foods in the HHs in the last 7 days
  mutate(lact_m = ifelse(age<=1, moid, NA))  # list up mother's y4_hhid in lact_m


## ------------------------------------------------------------------------------------------------------------
df_lactm <- dataB_lact %>% 
  count(y4_hhid, lact_m) %>% 
  filter(lact_m<=32) %>%   # excluding mother living outside (#98)
  select(-n) %>% 
  mutate(lact=1) %>% 
  rename(indidy4=lact_m)  # rename lact_m to indidy4 before merging


## ------------------------------------------------------------------------------------------------------------
u2 <-  read_csv("2_data/files/npsy4.child.anthro.csv")

u2 <- u2 %>%
  mutate(kcalreq = case_when(
    age_months <= 2 ~ 0,   # only breast feeding - no food intake
    age_months >= 3 & age_months <= 5 ~ 76,  # energy from food is 76kcal per day for 3-5 months of age
    age_months >= 6 & age_months <= 8 ~ 269,  # 269kcal per day for 6-8 months of age
    age_months >= 9 & age_months <= 11 ~ 451,   # 451kcal per day for 9-11 months of age
    age_months >= 12 & age_months <= 23 ~ 746)) %>%  # 746kcal per day for 12-23 months of age
  filter(age_months<=23)  # select children below 24 months


## ------------------------------------------------------------------------------------------------------------
afeu2 <- u2 %>% 
  mutate(afeu2 = kcalreq/2346) %>% # 1AFE = 2346kcal
  select(y4_hhid, indidy4, afeu2)

write_csv(afeu2, "2_data/files/afeu2.csv") # complete.


## ------------------------------------------------------------------------------------------------------------
df_afe <- read_csv("2_data/files/afeabove2y.csv")

dataB_afe <- left_join(dataB_lact, df_afe, by = c('sex', 'age'))  # merge with AFE except children below 24 months

eathh <- dataB_afe %>% 
  distinct(y4_hhid)


## ------------------------------------------------------------------------------------------------------------
dataB_afe2 <- left_join(dataB_afe, df_lactm, by = c('y4_hhid', 'indidy4'))  # merge with df_lactm (list of lactating mothers, see 4.2) and dataB_afe to identify lactating women with 1 in lact

afebylact <- read_csv("2_data/files/AFEbylact.csv") 

dataB_afe3 <- left_join(dataB_afe2, afebylact, by = c('lact', 'sex', 'age'))  # merge with AFE of lactating women by age


## ------------------------------------------------------------------------------------------------------------
df_u2 <- read_csv("2_data/files/afeu2.csv")

dataB_afe4 <- left_join(dataB_afe3, df_u2, by = c('y4_hhid', 'indidy4'))  # merge with df_u2


## ------------------------------------------------------------------------------------------------------------
dataB_afe5 <- dataB_afe4 %>%
  mutate(afe = if_else(lact==1, afe_l, afe, missing=afe))

dataB_afe6 <- dataB_afe5 %>%
  mutate(afe = if_else(afeu2>=0, afeu2, afe, missing=afe))

dataB_afe6 <-  dataB_afe6 %>% 
  select(y4_hhid, indidy4, afe)


## ------------------------------------------------------------------------------------------------------------
dataB_afe7 <- dataB_afe6 %>% 
  group_by(y4_hhid) %>% 
  summarise(afehh = sum(afe, na.rm = T))

write_csv(dataB_afe7, "2_data/files/hhafe.csv")


## ------------------------------------------------------------------------------------------------------------
miss_var_summary(dataB_afe7)


## ------------------------------------------------------------------------------------------------------------
## 4. energy requirement for lactating women - identify lactating women (i.e. the biological mother of children below 24 months of age)
# 2.4.1. filter & identify biological mothers of children 0-23 months of age
dataB <- read_csv("2_data/files/dataB.csv")

# change filter here!
dataB_lact <- dataB %>% 
  select(y4_hhid, indidy4, sex, age, moid, eat7d) %>% 
  # filter(eat7d == 1) %>%     # select only women who ate foods in the HHs in the last 7 days
  mutate(lact_m = ifelse(age<=1, moid, NA))  # list up mother's y4_hhid in lact_m

# 2.4.2. make a list of lactating mothers with hhid and indid
df_lactm <- dataB_lact %>% 
  count(y4_hhid, lact_m) %>% 
  filter(lact_m<=32) %>%   # excluding mother living outside (#98)
  select(-n) %>% 
  mutate(lact=1) %>% 
  rename(indidy4=lact_m)  # rename lact_m to indidy4 before merging

# 2.5. energy requirement of children below 24 months
# 2.5.1. Use energy need from complementary foods in developing countries - see Table 10 (p 51), Brown et al., 1998
u2 <-  read_csv("2_data/files/npsy4.child.anthro.csv")

u2 <- u2 %>%
  mutate(kcalreq = case_when(
    age_months <= 2 ~ 0,   # only breast feeding - no food intake
    age_months >= 3 & age_months <= 5 ~ 76,  # energy from food is 76kcal per day for 3-5 months of age
    age_months >= 6 & age_months <= 8 ~ 269,  # 269kcal per day for 6-8 months of age
    age_months >= 9 & age_months <= 11 ~ 451,   # 451kcal per day for 9-11 months of age
    age_months >= 12 & age_months <= 23 ~ 746)) %>%  # 746kcal per day for 12-23 months of age
  filter(age_months<=23)  # select children below 24 months

# 2.5.2. AFE calculation for children below 24 months
afeu2 <- u2 %>% 
  mutate(afeu2 = kcalreq/2346) %>% # 1AFE = 2346kcal
  select(y4_hhid, indidy4, afeu2)

# write_csv(afeu2, "2_data/files/afeu2.csv")
## 2.6. calculate total AFE in the HHs
# 2.6.1. open AFE file for abeve 2y of age and merge the values with individuals

df_afe <- read_csv("2_data/files/afeabove2y.csv")

dataB_afe <- left_join(dataB_lact, df_afe, by = c('sex', 'age'))  # merge with AFE except children below 24 months

eathh <- dataB_afe %>% 
  distinct(y4_hhid)

## 2.6.2. merge with the list of lactating women and merge with AFE value by age

dataB_afe2 <- left_join(dataB_afe, df_lactm, by = c('y4_hhid', 'indidy4'))  # merge with df_lactm (list of lactating mothers, see 4.2) and dataB_afe to identify lactating women with 1 in lact

afebylact <- read_csv("2_data/files/AFEbylact.csv") 

dataB_afe3 <- left_join(dataB_afe2, afebylact, by = c('lact', 'sex', 'age'))  # merge with AFE of lactating women by age

## 2.6.3. open AFE values for below 24 months and merge in the file
# df_u2 <- read_csv("2_data/files/afeu2.csv") # no files are saved in chunk as not to override
df_u2 <- afeu2

dataB_afe4 <- left_join(dataB_afe3, df_u2, by = c('y4_hhid', 'indidy4'))  # merge with df_u2

## 2.6.4. replace AFE for lactating women (lact_1) and AFE for below 24 months (afeu2)
dataB_afe5 <- dataB_afe4 %>%
  mutate(afe = if_else(lact==1, afe_l, afe, missing=afe))

dataB_afe6 <- dataB_afe5 %>%
  mutate(afe = if_else(afeu2>=0, afeu2, afe, missing=afe))

dataB_afe6 <-  dataB_afe6 %>% 
  select(y4_hhid, indidy4, afe)

## 2.6.5. Calculate total AFE in each HH
dataB2_afe7 <- dataB_afe6 %>% 
  group_by(y4_hhid) %>% 
  summarise(afehhmax = sum(afe, na.rm = T))

write_csv(dataB2_afe7, "2_data/files/hhafe2.csv") # indicate second appraoch to calculating AFE

miss_var_summary(dataB2_afe7)

## ------------------------------------------------------------------------------------------------------------
miss_var_summary(dataB2_afe7)


## ------------------------------------------------------------------------------------------------------------
pres <- 6
## 4. energy requirement for lactating women - identify lactating women (i.e. the biological mother of children below 24 months of age)
# 2.4.1. filter & identify biological mothers of children 0-23 months of age
dataB <- read_csv("2_data/files/dataB.csv")

# change filter here!
dataB_lact <- dataB %>% 
  # select(y4_hhid, indidy4, sex, age, moid, eat7d) %>% 
  filter(eat7d == 1 & moabs <= pres) %>%     # select only women who ate foods in the HHs in the last 7 days
  mutate(lact_m = ifelse(age<=1, moid, NA))  # list up mother's y4_hhid in lact_m

# 2.4.2. make a list of lactating mothers with hhid and indid
df_lactm <- dataB_lact %>% 
  count(y4_hhid, lact_m) %>% 
  filter(lact_m<=32) %>%   # excluding mother living outside (#98)
  select(-n) %>% 
  mutate(lact=1) %>% 
  rename(indidy4=lact_m)  # rename lact_m to indidy4 before merging

# 2.5. energy requirement of children below 24 months
# 2.5.1. Use energy need from complementary foods in developing countries - see Table 10 (p 51), Brown et al., 1998
u2 <-  read_csv("2_data/files/npsy4.child.anthro.csv")

u2 <- u2 %>%
  mutate(kcalreq = case_when(
    age_months <= 2 ~ 0,   # only breast feeding - no food intake
    age_months >= 3 & age_months <= 5 ~ 76,  # energy from food is 76kcal per day for 3-5 months of age
    age_months >= 6 & age_months <= 8 ~ 269,  # 269kcal per day for 6-8 months of age
    age_months >= 9 & age_months <= 11 ~ 451,   # 451kcal per day for 9-11 months of age
    age_months >= 12 & age_months <= 23 ~ 746)) %>%  # 746kcal per day for 12-23 months of age
  filter(age_months<=23)  # select children below 24 months

# 2.5.2. AFE calculation for children below 24 months
afeu2 <- u2 %>% 
  mutate(afeu2 = kcalreq/2346) %>% # 1AFE = 2346kcal
  select(y4_hhid, indidy4, afeu2)

# write_csv(afeu2, "2_data/files/afeu2.csv")
## 2.6. calculate total AFE in the HHs
# 2.6.1. open AFE file for abeve 2y of age and merge the values with individuals

df_afe <- read_csv("2_data/files/afeabove2y.csv")

dataB_afe <- left_join(dataB_lact, df_afe, by = c('sex', 'age'))  # merge with AFE except children below 24 months

eathh <- dataB_afe %>% 
  distinct(y4_hhid)

## 2.6.2. merge with the list of lactating women and merge with AFE value by age

dataB_afe2 <- left_join(dataB_afe, df_lactm, by = c('y4_hhid', 'indidy4'))  # merge with df_lactm (list of lactating mothers, see 4.2) and dataB_afe to identify lactating women with 1 in lact

afebylact <- read_csv("2_data/files/AFEbylact.csv") 

dataB_afe3 <- left_join(dataB_afe2, afebylact, by = c('lact', 'sex', 'age'))  # merge with AFE of lactating women by age

## 2.6.3. open AFE values for below 24 months and merge in the file
# df_u2 <- read_csv("2_data/files/afeu2.csv") # no files are saved in chunk as not to override
df_u2 <- afeu2

dataB_afe4 <- left_join(dataB_afe3, df_u2, by = c('y4_hhid', 'indidy4'))  # merge with df_u2

## 2.6.4. replace AFE for lactating women (lact_1) and AFE for below 24 months (afeu2)
dataB_afe5 <- dataB_afe4 %>%
  mutate(afe = if_else(lact==1, afe_l, afe, missing=afe))

dataB_afe6 <- dataB_afe5 %>%
  mutate(afe = if_else(afeu2>=0, afeu2, afe, missing=afe))

dataB_afe6 <-  dataB_afe6 %>% 
  select(y4_hhid, indidy4, afe)

## 2.6.5. Calculate total AFE in each HH
dataB3_afe7 <- dataB_afe6 %>% 
  group_by(y4_hhid) %>% 
  summarise(afehhmin = sum(afe, na.rm = T)) # rename for merge

write_csv(dataB3_afe7, "2_data/files/hhafe3.csv") # indicate second appraoch to calculating AFE

miss_var_summary(dataB3_afe7)


## ------------------------------------------------------------------------------------------------------------
dataB_compl <- dataB_afe7 %>% 
  left_join(dataB2_afe7, by = "y4_hhid") %>% 
  left_join(dataB3_afe7, by = "y4_hhid")

miss_var_summary(dataB_compl) # some missing, check once exclusions are removed

write_csv(dataB_compl, "2_data/final/afe_summaries.csv")


## ------------------------------------------------------------------------------------------------------------
## 4. energy requirement for lactating women - identify lactating women (i.e. the biological mother of children below 24 months of age)
# 2.4.1. filter & identify biological mothers of children 0-23 months of age
dataB <- read_csv("2_data/files/dataB.csv")

# change filter here!
dataB_lact <- dataB %>% 
  # select(y4_hhid, indidy4, sex, age, moid, eat7d) %>% 
  # filter(eat7d == 1) %>%     # select only women who ate foods in the HHs in the last 7 days
  mutate(lact_m = ifelse(age<=1, moid, NA))  # list up mother's y4_hhid in lact_m
# change here: seems to assume no additional energy requirements when breastfeeding after 1 year

# 2.4.2. make a list of lactating mothers with hhid and indid
df_lactm <- dataB_lact %>% 
  count(y4_hhid, lact_m) %>% 
  filter(lact_m<=32) %>%   # excluding mother living outside (#98)
  select(-n) %>% 
  mutate(lact=1) %>% 
  rename(indidy4=lact_m)  # rename lact_m to indidy4 before merging

# 2.5. energy requirement of children below 24 months
# 2.5.1. Use energy need from complementary foods in developing countries - see Table 10 (p 51), Brown et al., 1998
u2 <-  read_csv("2_data/files/npsy4.child.anthro.csv")

u2 <- u2 %>%
  mutate(kcalreq = case_when(
    age_months <= 2 ~ 0,   # only breast feeding - no food intake
    age_months >= 3 & age_months <= 5 ~ 76,  # energy from food is 76kcal per day for 3-5 months of age
    age_months >= 6 & age_months <= 8 ~ 269,  # 269kcal per day for 6-8 months of age
    age_months >= 9 & age_months <= 11 ~ 451,   # 451kcal per day for 9-11 months of age
    age_months >= 12 & age_months <= 23 ~ 746)) %>%  # 746kcal per day for 12-23 months of age
  filter(age_months<=23)  # select children below 24 months

# 2.5.2. AFE calculation for children below 24 months
afeu2 <- u2 %>% 
  mutate(afeu2 = kcalreq/2346) %>% # 1AFE = 2346kcal
  select(y4_hhid, indidy4, afeu2)

# write_csv(afeu2, "2_data/files/afeu2.csv")
## 2.6. calculate total AFE in the HHs
# 2.6.1. open AFE file for abeve 2y of age and merge the values with individuals

df_afe <- read_csv("2_data/files/afeabove2y.csv")

dataB_afe <- left_join(dataB_lact, df_afe, by = c('sex', 'age'))  # merge with AFE except children below 24 months

eathh <- dataB_afe %>% 
  distinct(y4_hhid)

## 2.6.2. merge with the list of lactating women and merge with AFE value by age

dataB_afe2 <- left_join(dataB_afe, df_lactm, by = c('y4_hhid', 'indidy4'))  # merge with df_lactm (list of lactating mothers, see 4.2) and dataB_afe to identify lactating women with 1 in lact

afebylact <- read_csv("2_data/files/AFEbylact.csv") 

dataB_afe3 <- left_join(dataB_afe2, afebylact, by = c('lact', 'sex', 'age'))  # merge with AFE of lactating women by age

## 2.6.3. open AFE values for below 24 months and merge in the file
# df_u2 <- read_csv("2_data/files/afeu2.csv") # no files are saved in chunk as not to override
df_u2 <- afeu2

dataB_afe4 <- left_join(dataB_afe3, df_u2, by = c('y4_hhid', 'indidy4'))  # merge with df_u2

## 2.6.4. replace AFE for lactating women (lact_1) and AFE for below 24 months (afeu2)
dataB_afe5 <- dataB_afe4 %>%
  mutate(afe = if_else(lact==1, afe_l, afe, missing=afe))

dataB_afe9 <- dataB_afe5 %>%
  mutate(afe = if_else(afeu2>=0, afeu2, afe, missing=afe))

dataB_afe8 <-  dataB_afe9 %>% 
  select(y4_hhid, indidy4, afe_all = afe) %>% # rename for summarising
  full_join(select(dataB, y4_hhid, indidy4, eat7d, moabs)) %>% 
  mutate(
    afe_7d = ifelse(eat7d==1, afe_all, 0),
    moabs = ifelse(is.na(moabs), 6, moabs), # several missing, somewhat even between consumers and non-consume
    mopres = 12-moabs,
    mopres7d = ifelse(eat7d == 1, 12-moabs, 0),
    hh_person = 1,
    eat7d = ifelse(eat7d == 2, 0, eat7d),
    afe_7d_mo = afe_7d * mopres,
    afe_all_mo = afe_all * mopres)

afe_mopres <- dataB_afe8 %>% 
  group_by(y4_hhid) %>% 
  summarise(across(is.numeric, ~sm(.x))) %>% 
  select(!c(moabs, indidy4)) 
miss_var_summary(afe_mopres)

write_csv(dataB_afe8, "2_data/results/afe_detailed.csv") # indicate second appraoch to calculating AFE
write_csv(afe_mopres, "2_data/results/afe_mopres_hh.csv") # indicate second appraoch to calculating AFE

# ATTENTION 7 individuals have no AFE estimate when they should, unclear why

miss_var_summary(dataB_afe8)
miss_var_summary(afe_mopres)


## ----general ame---------------------------------------------------------------------------------------------
hh_dem <- readRDS("2_data/files/hh_dem.RDS")
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
hh_dem <- clear.labels(hh_dem)
# install.packages("devtools")
# devtools::install_github("dzvoti/hcesNutR")
# library(hcesNutR) # not published yet
# Import data of the roster and health modules of the IHS5 survey

# adulteq given by LSMS
hh_sec_d <- read_csv("2_data/files/hh_sec_d.csv")

# Import data of the AME/AFE factors and specifications
ame_factors <-
  read.csv("2_data/reference/IHS5_AME_FACTORS_vMAPS.csv") |>
  janitor::clean_names()


## ----ame all members-----------------------------------------------------------------------------------------
# Extra energy requirements for pregnancy and Illness
pregnantPersons2 <- hh_sec_d |>
  # left_join(select(hh_dem, y4_hhid, indidy4, consumer), by = c("y4_hhid", "indidy4")) %>%  # filter out non-consumers
  # filter(consumer == "yes") %>% 
  setDT() %>% 
  haven::as_factor() %>% # missing package
  dplyr::filter(hh_d37 == "yes") |> 
  # NOTE: has given birth to a child in past 24 months, including stillbirths
  dplyr::mutate(ame_preg = 0.11, afe_preg = 0.14) |> 
  dplyr::select(y4_hhid, ame_preg, afe_preg) %>% 
  group_by(y4_hhid) %>%  # remove duplicates, i.e. multiple pregnancies in households
  dplyr::summarize(
    ame_preg = sum(ame_preg),
    afe_preg = sum(afe_preg)
  )

# Process the roster data and rename variables to be more intuitive
aMFe_summaries2 <- hh_dem %>% 
  # filter(consumer == "yes" & age>3) %>%  # own code! if not a consumer no need to count unless it's a baby
  # Rename the variables to be more intuitive
  dplyr::rename(age_y = age) %>% 
  dplyr::left_join(ame_factors, by = c("age_y" = "age")) |> 
  dplyr::mutate(
    ame_base = dplyr::case_when(sex == "male" ~ ame_m, sex == "female" ~ ame_f),
    afe_base = dplyr::case_when(sex == "male" ~ afe_m, sex == "female" ~ afe_f) ) |>
  # Dietary requirements for children under 1 year old
  dplyr::mutate(
    ame_lac = dplyr::case_when(age_y < 2 ~ 0.19),
    afe_lac = dplyr::case_when(age_y < 2 ~ 0.24)
  ) |>
  dplyr::rowwise() |>
  # TODO: Will it not be better to have the pregnancy values added at the same time here?
  dplyr::mutate(ame = sum(c(ame_base, ame_lac), na.rm = TRUE), # delete ame_spec NA
                afe = sum(c(afe_base, afe_lac), na.rm = TRUE)) |> # delete afe_spec NA
  # Calculate number of individuals in the households
  dplyr::group_by(y4_hhid) |>
  dplyr::summarize(
    hh_persons = dplyr::n(),
    hh_ame = sm(ame),
    hh_afe = sm(afe)
  ) |>
  # Merge with the pregnancy and illness data
  dplyr::left_join(pregnantPersons2, by = "y4_hhid") |>
  dplyr::rowwise() |>
  dplyr::mutate(hh_ame = sum(c(hh_ame, ame_preg), na.rm = T),
                hh_afe = sum(c(hh_afe, afe_preg), na.rm = T)) |>
  dplyr::ungroup() |>
  # Fix single household factors
  dplyr::mutate(
    hh_ame = dplyr::if_else(hh_persons == 1, 1, hh_ame),
    hh_afe = dplyr::if_else(hh_persons == 1, 1, hh_afe)
  ) %>% 
  dplyr::select(y4_hhid, hh_persons, hh_ame, hh_afe) 


## ----present hh members--------------------------------------------------------------------------------------
ex <- pres # set number of months member has to be absent to be excluded from count

# Extra energy requirements for pregnancy and Illness
pregnantPersons3 <- hh_sec_d |>
  left_join(select(hh_dem, y4_hhid, indidy4, consumer, absence), by = c("y4_hhid", "indidy4")) %>%  # filter out members absent for certain number of months
  filter(absence <= ex) %>% # independent on whether they were reported to have been consumers
  as_factor() %>% 
  dplyr::filter(hh_d37 == "yes") |> 
  # NOTE: has given birth to a child in past 24 months, including stillbirths
  dplyr::mutate(ame_preg = 0.11, afe_preg = 0.14) |> 
  dplyr::select(y4_hhid, ame_preg, afe_preg) %>% 
  group_by(y4_hhid) %>%  # remove duplicates, i.e. multiple pregnancies in households
  dplyr::summarize(
    ame_preg = sm(ame_preg),
    afe_preg = sm(afe_preg)
  )

# Process the roster data and rename variables to be more intuitive
aMFe_summaries3 <- hh_dem |>
  filter(absence <= ex) %>% # independent on whether they were reported to have been consumers
  # Rename the variables to be more intuitive
  dplyr::rename(age_y = age) %>% 
  dplyr::left_join(ame_factors, by = c("age_y" = "age")) |> 
  dplyr::mutate(
    ame_base = dplyr::case_when(sex == "male" ~ ame_m, sex == "female" ~ ame_f),
    afe_base = dplyr::case_when(sex == "male" ~ afe_m, sex == "female" ~ afe_f) ) |>
  # Dietary requirements for children under 1 year old
  dplyr::mutate(
    ame_lac = dplyr::case_when(age_y < 2 ~ 0.19),
    afe_lac = dplyr::case_when(age_y < 2 ~ 0.24)
  ) |>
  dplyr::rowwise() |>
  # TODO: Will it not be better to have the pregnancy values added at the same time here?
  dplyr::mutate(ame = sum(c(ame_base, ame_lac), na.rm = TRUE), # delete ame_spec NA
                afe = sum(c(afe_base, afe_lac), na.rm = TRUE)) |> # delete afe_spec NA
  # Calculate number of individuals in the households
  dplyr::group_by(y4_hhid) |>
  dplyr::summarize(
    hh_persons = dplyr::n(),
    hh_ame = sm(ame),
    hh_afe = sm(afe)
  ) |>
  # Merge with the pregnancy and illness data
  dplyr::left_join(pregnantPersons3, by = "y4_hhid") |>
  dplyr::rowwise() |>
  dplyr::mutate(hh_ame = sum(c(hh_ame, ame_preg), na.rm = T),
                hh_afe = sum(c(hh_afe, afe_preg), na.rm = T)) |>
  dplyr::ungroup() |>
  # Fix single household factors
  dplyr::mutate(
    hh_ame = dplyr::if_else(hh_persons == 1, 1, hh_ame),
    hh_afe = dplyr::if_else(hh_persons == 1, 1, hh_afe)
  ) %>% 
  dplyr::select(y4_hhid, hh_persons, hh_ame, hh_afe) 


## ----ame hcesnutr--------------------------------------------------------------------------------------------
# ame_spec_factors <- # not needed
#   read.csv("2_data/reference/IHS5_AME_SPEC_vMAPS.csv") |>
#   janitor::clean_names() |>
#   # Rename the population column to cat and select the relevant columns
#   dplyr::rename(cat = population) |>
#   dplyr::select(cat, ame_spec, afe_spec)

# Extra energy requirements for pregnancy and Illness
pregnantPersons <- hh_sec_d |>
  left_join(select(hh_dem, y4_hhid, indidy4, consumer), by = c("y4_hhid", "indidy4")) %>%  # filter out non-consumers
  filter(consumer == "yes") %>% 
  as_factor() %>% 
  dplyr::filter(hh_d37 == "yes") |> 
  # NOTE: has given birth to a child in past 24 months, including stillbirths -> best pregnancy proxy available
  dplyr::mutate(ame_preg = 0.11, afe_preg = 0.14) |> 
  dplyr::select(y4_hhid, ame_preg, afe_preg) %>% 
  group_by(y4_hhid) %>%  # remove duplicates, i.e. multiple pregnancies in households
  dplyr::summarize(
    ame_preg = sum(ame_preg),
    afe_preg = sum(afe_preg)
  )

# Process the roster data and rename variables to be more intuitive
aMFe_summaries <- hh_dem %>% 
  filter(consumer == "yes") %>%  # own code! most 0 aged will be listed as consumers
  # Rename the variables to be more intuitive
  dplyr::rename(age_y = age) %>% 
# , age_m = hh_b05b) |> # no month as age given as month/year of birth confidential
  # dplyr::mutate(age_m_total = (age_y * 12 + age_m)) |> 
  # Add the AME/AFE factors to the roster data
  dplyr::left_join(ame_factors, by = c("age_y" = "age")) |> 
  dplyr::mutate(
    ame_base = dplyr::case_when(sex == "male" ~ ame_m, sex == "female" ~ ame_f),
    afe_base = dplyr::case_when(sex == "male" ~ afe_m, sex == "female" ~ afe_f)
    # TZA LSMS does not record monthly age
    # age_u1_cat = dplyr::case_when( 
    #   # NOTE: Round here will ensure that decimals are not omited in the calculation.
    #   round(age_m_total) %in% 0:5 ~ "0-5 months",
    #   round(age_m_total) %in% 6:8 ~ "6-8 months",
    #   round(age_m_total) %in% 9:11 ~ "9-11 months"
    # )
  ) |>
  # Add the AME/AFE factors for the specific age categories
  # dplyr::left_join(ame_spec_factors, by = c("age_u1_cat" = "cat")) |> # not applicable
  # Dietary requirements for children under 1 year old
  dplyr::mutate(
    ame_lac = dplyr::case_when(age_y < 2 ~ 0.19),
    afe_lac = dplyr::case_when(age_y < 2 ~ 0.24)
  ) |>
  dplyr::rowwise() |>
  # TODO: Will it not be better to have the pregnancy values added at the same time here?
  dplyr::mutate(ame = sum(c(ame_base, ame_lac), na.rm = TRUE), # delete ame_spec NA
                afe = sum(c(afe_base, afe_lac), na.rm = TRUE)) |> # delete afe_spec NA
  # Calculate number of individuals in the households
  dplyr::group_by(y4_hhid) |>
  dplyr::summarize(
    hh_persons = dplyr::n(),
    hh_ame = sm(ame),
    hh_afe = sm(afe)
  ) |>
  # Merge with the pregnancy and illness data
  dplyr::left_join(pregnantPersons, by = "y4_hhid") |>
  dplyr::rowwise() |>
  dplyr::mutate(hh_ame = sum(c(hh_ame, ame_preg), na.rm = T),
                hh_afe = sum(c(hh_afe, afe_preg), na.rm = T)) |>
  dplyr::ungroup() |>
  # Fix single household factors
  dplyr::mutate(
    hh_ame = dplyr::if_else(hh_persons == 1, 1, hh_ame),
    hh_afe = dplyr::if_else(hh_persons == 1, 1, hh_afe)
  ) %>% 
  dplyr::select(y4_hhid, hh_persons, hh_ame, hh_afe) %>% 
  left_join(select(aMFe_summaries2, y4_hhid, ame_full = hh_ame), by = "y4_hhid")

saveRDS(aMFe_summaries, "2_data/final/aMFe_summaries.RDS", compress = T)

miss_var_summary(aMFe_summaries)



## ----compare ames--------------------------------------------------------------------------------------------
amecomp <- aMFe_summaries %>% 
  select(y4_hhid, hh_persons, amehh = hh_ame) %>% 
  left_join(select(aMFe_summaries2, y4_hhid, amehh_max = hh_ame, hh_max = hh_persons), by ="y4_hhid") %>% 
  left_join(select(aMFe_summaries3, y4_hhid, amehh_min = hh_ame, hh_min = hh_persons), by = "y4_hhid") 

write_csv(amecomp, "2_data/final/ame_summaries.csv")


## ------------------------------------------------------------------------------------------------------------
ame_summaries <- read_csv("2_data/final/ame_summaries.csv")
afe_summaries <- read_csv("2_data/final/afe_summaries.csv")

aFMe_summaries <- ame_summaries %>% 
  left_join(afe_summaries, by = "y4_hhid") %>% 
  mutate(
    hh_min = replace_na(hh_min, 0), # will allow to find the hhs for which the min values were imputed
    afehhmin = ifelse(is.na(afehhmin), afehh/hh_persons, afehhmin), # for it not to be 0 but reflect some sort of lower limit that acknowledges some presence in the household throughout the year
    amehh_min = ifelse(is.na(amehh_min), amehh/hh_persons, amehh_min)
)

miss_var_summary(aFMe_summaries)
# in 15/20 cases minimum missing due to prolonged absence, replace with average


write_csv(aFMe_summaries, "2_data/final/aFMe_summaries.csv")


## ----ame other, eval=FALSE-----------------------------------------------------------------------------------
# # not necessary just a duplication - exclusion of region missing households to be integrated elsewhere
# # individual level
# hh_membs <- hh_dem %>%
#   select(y4_hhid, indidy4, sex, age, consumer, presence, absence, three_mo = hh_b09_1) %>%
#   # add age groups
#   mutate(
#       age_gp = case_when(
#       age <= 2 ~ "Infants (6–23 months)",
#       age > 2 & age <= 5  ~ "Children (24–59 months)",
#       age > 5 & age <= 17 ~ "Youth (5–17 yrs)",
#       age > 17 & age <= 65 ~ "Adults (18–65 yrs)",
#       age > 65             ~ "Elderly (> 65 yrs)"
#       ),
#   # Convert to factor
#     age_gp = factor(
#       age_gp,
#       level = c("Infants (6–23 months)", "Children (24–59 months)", "Youth (5–17 yrs)", "Adults (18–65 yrs)", "Elderly (> 65 yrs)"))) %>%
#   # add adult male equivalent for energy requirements
#   mutate(sex = as.character(sex),
#          count = 1) %>% # new var for presence
#   left_join(select(weights, 1:3), by =c("sex", "age_gp")) %>%
#   group_by(y4_hhid, sex, age_gp, energy) %>% # hh members by age group and sex
#   summarise(
#     count_cons = sum(count[consumer == "yes"]),
#     count_present = sum(count[three_mo == "yes"]), # present for 3 months or more in past 12 months
#     count_all = sum(count) # all household members independent of consumption
#     ) %>%
#   mutate( # calculate ame
#     ame = count_cons * energy,
#     ame_pres = count_present *energy,
#     ame_all = count_all * energy) #
# 
# # household information containing ame --> ideally only meta data without the ame, keep as not to break code down the line...
# household <- hh_membs %>%
#   mutate(y4_hhid = as.character(y4_hhid)) %>%
#   group_by(y4_hhid) %>%
#   summarise(
#     ame_coates = sum(ame), # hh ame
#     ame_call = sum(ame_all),
#     ame_prs = sum(ame_pres),
#     hh_membs = sum(count_all), # compare with LSMS info
#     hh_consumers = sum(count_cons)
#   ) %>%
#   left_join(select(consumptionNPS4, c(y4_hhid, hhsize, adulteq, region, intmonth)), by = ("y4_hhid")) %>%
#   # add aMFe_summaries to have all in one file?
#   setDT() %>%
#   mutate(region = str_to_title(as_factor(region))) %>%
#   left_join(zones, by = "region")
# 
# miss_var_summary(household)
# ex_no_region <- household[is.na(region)] # for several missing -> exclude at later step

