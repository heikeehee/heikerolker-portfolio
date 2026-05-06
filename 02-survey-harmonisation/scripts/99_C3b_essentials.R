## ----set-up--------------------------------------------------------------------------------------------------
# load packages
library(tidyverse)
library(data.table)
library(Hmisc)
library(gt)
library(readxl)
library(naniar)


## ------------------------------------------------------------------------------------------------------------
# copy from C3a
# calculations
sm <- function(x) sum(x, na.rm = TRUE)
rd <- function(df) df %>% dplyr::mutate_if(is.numeric, round, 1)
md <- function(x) median(x, na.rm=TRUE)
mn <- function(x) mean(x, na.rm=TRUE)


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


## ------------------------------------------------------------------------------------------------------------
t<-1000


## ------------------------------------------------------------------------------------------------------------
name_months <- function(df){
  df %>% 
    mutate(
      month = fcase(
      month == 1, "January",
      month == 2, "February",
      month == 3, "March",
      month == 4, "April",
      month == 5, "May",
      month == 6, "June",
      month == 7, "July",
      month == 8, "August",
      month == 9, "September",
      month == 10, "October",
      month == 11, "November",
      month == 12, "December"),
      month = factor(month, 
                     levels = c("January", "February", "March", "April", "May", "June",
                                "July", "August", "September", "October", "November", "December")))
}


## ------------------------------------------------------------------------------------------------------------
calc.diffs <- function(df, fun){ # add element for function
  df %>% 
    # summarise(across(c(tot.crude:bootTt), ~ fun(.x))) %>% 
    mutate(
      mean = (tot.spat + tot.temp + bootSt + bootTt)/4,
      diffccS = tot.crude - tot.spat, # calculate difference between proposed method and given data
      diffccT = tot.crude - tot.temp,
      diffcbS = tot.crude - bootSt,
      diffcbT = tot.crude - bootTt)
} 

calc.diff.stats <- function(df){
  df %>% 
    summarise(
      across(c(diffccS:diffcbT), ~ sd(.x, na.rm=T), .names = "sd.{.col}"), # sd first as following alters diff vars
      across(c(diffccS:diffcbT), ~ mn(.x)),
      n = n()
    ) %>% 
    mutate(
      se.ccS = sd.diffccS/sqrt(n),
      se.ccT = sd.diffccT/sqrt(n),
      se.cbS = sd.diffcbS/sqrt(n),
      se.cbT = sd.diffcbT/sqrt(n),
      # confidence interval - repeat for all
      lower.ci.ccS = diffccS - qt(1 - (0.05/2), n -1) * se.ccS,
      upper.ci.ccS = diffccS + qt(1 - (0.05/2), n -1) * se.ccS,
      lower.ci.ccT = diffccT - qt(1 - (0.05/2), n -1) * se.ccT,
      upper.ci.ccT = diffccT + qt(1 - (0.05/2), n -1) * se.ccT,
      lower.ci.cbS = diffcbS - qt(1 - (0.05/2), n -1) * se.cbS,
      upper.ci.cbS = diffcbS + qt(1 - (0.05/2), n -1) * se.cbS,
      lower.ci.cbT = diffcbT - qt(1 - (0.05/2), n -1) * se.cbT,
      upper.ci.cbT = diffcbT + qt(1 - (0.05/2), n -1) * se.cbT
    )
}

