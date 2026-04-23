#
library(tidyverse)
library(stringr)
library(stringi)
library(data.table)
library(Hmisc)
library(dplyr)
library(haven)
library(naniar)
library(lubridate)
library(crosstable)


# Functions for data preparation

# show labels
firstfun <- function(df){
  # list labels as imported with haven
  lapply(identifiers_ag, attr, "label") # variable description
  
  # decode variables
  lapply(identifiers_ag, attr, "labels") # decodes variables
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

prep <- function(df, season = "name"){
  df %>% 
    setDT() %>% 
    add_column(season)}

strip_colnames <- function(df, pattern, sub){
  for ( col in 1:ncol(df)){
    colnames(df)[col] <-  sub(pattern, sub, colnames(df)[col])
  }
  df
}

bind_dt <- function(df1, df2){
  df1 %>% 
    bind_rows(df2) %>% 
    clean_up()}

prep_labs <- function(df){
  labs <- lapply(df, attr, "label")
  unlist(labs, use.names = T) 
}

crops_list <- list(
  "fruits" = c(
    "coconut", "mango", "plums", "banana", "mandarin",
    "lime", "passion fruit", "star fruit", "avocado", "orange",
    "guava", "lemon", "papaw", "jack fruit", "pineapple",
    "custard apple", "apples", "rambutan", "peaches", "pears",
    "durian", "pomegranate", "malay apple", "bread fruit",
    "bilimbi", "date", "grapes", "pomelo", "grapefruit",
    "watermelon", "kapok", "persimmon", "soursop"
  ),
  "vegetables" = c(
    "spinach", "onions", "okra", "pumpkin", "pepper",
    "tomatoes", "cabbage", "chillies", "eggplant", "cauliflower",
    "cucumber", "seaweed", "amaranth", "garlic"
  ),
  "grains & cereals" = c(
    "finger millet", "maize", "sorghum", "paddy", "wheat",
    "barley", "bulrush millet"
  ),
  "roots & tubers" = c(
    "potatoes","sweet potatoes", "yams", "cassava", "carrot",
    "plantains"
  ),
  "legumes" = c(
    "cow peas", "pigeon pea", "chick peas", "soybeans", "beans",
    "cocoyams", "fiwi", "field peas",  "peas"
    
  ),
  "cashcrops" = c(
    "cotton", "pyrethrum", "timber", "firewood/fodder", "medicinal plant",
    "bamboo", "fence tree", "sisal", "palm oil", "monkeybread",
    "tobacco", "rubber", "oil palm" 
  ),
  "nuts & seeds" = c(
    "sesame", "groundnut", "bambara nuts", "sunflower", "green gram",
    "cashew nut"),
  
  "spices" = c(   #alternatively: "misc"
    "coffee", "cardamom", "clove", "black pepper", "cinnamon",
    "cocoa", "sugar cane", "vanilla", "tamarind", "tea",
    "ginger", "nutmeg"),
  "other" = c("wattle", "other", "mitobo", "tungamaa") # only other & tungamaa appear
)

crops_list <- data.frame(cropid = unlist(crops_list), type = rep(names(crops_list), lengths(crops_list)))
crops_list <- crops_list %>%
  mutate(cropid = as_factor(cropid),
         type = as_factor(type))


clean_names <- function(df, list = list, x_name = "x_name"){
  wrong <- c("water mellon", "watermellon	","chickpeas", "soyabeans", "cocyams", "cowpeas",
             "chilies","irish potatoe", "amaranths", "palm oil", # "bulrush millet", "finger millet", 
             "pumpkins", "pear", "pearss", "plum", "plumss",
             "god fruit","egg plant", "cardammon", "cinammon", "other (specify)",
             "24", "25")
  right <- c("watermelon", "watermelon", "chick peas", "soybeans", "cocoyams", "cow peas",
             "chillies", "potatoe", "amaranth", "oil palm",# "millet", "millet", 
             "pumpkin", "pears", "pears","plums", "plums",
             "persimmon","eggplant", "cardamom", "cinnamon", "other",
             "yams", "cocoyams")
  #id <- c(cropid = "zaocode")
  
  df %>%
    as_factor() %>%
    mutate(across(where(is.factor), tolower)) %>%
    #rename(dplyr::any_of(id)) %>% # only rename if "zoacode" exists
    mutate(cropid = stri_replace_all_fixed(str = cropid,
                                           pattern = wrong,
                                           replacement = right,
                                           vectorize_all = FALSE)) %>%
    left_join(list, by = x_name) %>%
    relocate(type, .before = x_name) %>%
    # filter(type =! "cashcrops") %>% 
    # filter(cropid != "other") %>% 
    filter(!is.na(cropid))
}

labfix <- function(df1, df2){
  # put labels back (not sure why they are removed)
  labs <- lapply(df1, attr, "label")
  labs <- unlist(labs, use.names = T) # unlists into a named vector
  
  # re-add labels: https://statisticsglobe.com/add-variable-labels-data-frame-r
  label(df2) <- as.list(labs[match(names(df2), names(df2))])
}

# Household survey--------


## Merge file functions----
sm <- function(x) sum(x, na.rm=TRUE)
mn <- function(x) mean(x, na.rm=TRUE)

top2 <- function(x) quantile(x, probs = .99, na.rm=TRUE)

adlab <- function(x, lab, un='') {
  label(x) <- lab
  if(un != '') units(x) <- un
  x
}

rename <- function(x, n) setnames(x, names(n), n)

adlab <- function(x, lab, un='') {
  label(x) <- lab
  if(un != '') units(x) <- un
  x
}

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