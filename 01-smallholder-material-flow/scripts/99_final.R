# run all scripts


# https://bookdown.org/yihui/rmarkdown-cookbook/purl.html

knitr::purl("1_scripts/01_Crops.Rmd")
knitr::purl("1_scripts/01b_Yield_Gap.Rmd")
knitr::purl("1_scripts/02_Ag_produce.Rmd")
knitr::purl("1_scripts/03_Animals.Rmd")
knitr::purl("1_scripts/04_Animal_products.Rmd")
knitr::purl("1_scripts/04_Milk.Rmd")
knitr::purl("1_scripts/05_Destinations.Rmd")
knitr::purl("1_scripts/06a_Residue.Rmd")
knitr::purl("1_scripts/06_Summary.Rmd")

# last file before chapter, to be run in knit
knitr::purl("1_scripts/99_C3a.Rmd") 
knitr::purl("1_scripts/xx_results.Rmd")

# save files to specified location..

# run all R scripts...
source("1_scripts/00_functions1.R")
source("01_Crops.R")
source("01b_Yield_Gap.R")
source("02_Ag_produce.R")
source("03_Animals.R")
source("04_Animal_products.R")
source("04_Milk.R")
source("05_Destinations.R")
source("06a_Residue.R")
source("1_scripts/06.1_Survey_weighting.R")
# source("06_Summary.R")



