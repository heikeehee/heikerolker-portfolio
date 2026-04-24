# general packages needed for all chapters
if(!require(devtools)) {
  install.packages("devtools", repos = "http://cran.rstudio.com")
  library(devtools)
}

if(!require(bookdown)){
  devtools::install_github("rstudio/bookdown")
  library(bookdown)
}

if(!require(thesisdown)){
  devtools::install_github("ismayc/thesisdown")
  library(thesisdown)
}

if(!require(kableExtra)){
  devtools::install_github("haozhu233/kableExtra")
  library(kableExtra)
}

if(!require(tinytex)){
  devtools::install_github('yihui/tinytex')
  library(tinytex)
  options(tinytex.verbose = TRUE)
}

if(!require(flextable)){
  devtools::install_github("davidgohel/flextable")
  library(flextable)
}

if(!require(tidyverse)){
  install.packages("tidyverse")
  library(tidyverse)
}

if(!require(ggplot2)){
  install.packages("ggplot2")
  library(ggplot2)
}

if(!require(knitr)){
  install.packages("knitr")
  library(knitr)
}

if(!require(dplyr)){
  install.packages("dplyr")
  library(dplyr)
}

if(!require(data.table)){
  install.packages("data.table")
  library(data.table)
}

if(!require(Hmisc)){
  install.packages("Hmisc")
  library(Hmisc)
}

if(!require(stringi)){
  install.packages("stringi")
  library(stringi)
}

if(!require(stringr)){
  install.packages("stringr")
  library(stringr)
}

if(!require(haven)){
  install.packages("haven")
  library(haven)
}

if(!require(plotly)){
  install.packages("plotly")
  library(plotly)
}

if(!require(readxl)){
  install.packages("readxl")
  library(readxl)
}

if(!require(pander)){
  install.packages("pander")
  library(pander)
}

if(!require(RColorBrewer)){
  install.packages("RColorBrewer")
  library(RColorBrewer)
}
if(!require(viridis)){
  install.packages("viridis")
  library(viridis)
}
if(!require(hrbrthemes)){
  install.packages("hrbrthemes")
  library(hrbrthemes)
}
if(!require(ggthemes)){
  install.packages("ggthemes")
  library(ggthemes)
}

if(!require(ggimage)){
  install.packages("ggimage")
  library(ggimage)
}

if(!require(treemapify)){
  install.packages("treemapify")
  library(treemapify)
}

if(!require(purrr)){
  install.packages("purrr")
  library(purrr)
}

if(!require(here)){
  install.packages("here")
  library(here)
}
