# Packages — 01-smallholder-material-flow
# Install and load all dependencies for this project.
# Run once on a new machine before executing any other script.

packages_cran <- c(
  # Core
  "tidyverse", "data.table", "here", "purrr",
  # Data import
  "haven", "readxl",
  # Tables
  "knitr", "kableExtra",
  # Visualisation
  "ggplot2", "ggimage", "ggthemes", "treemapify",
  "plotly", "RColorBrewer", "viridis", "hrbrthemes",
  # Reporting
  "bookdown", "tinytex",
  # Utilities
  "Hmisc", "stringi", "stringr", "pander", "devtools"
)

for (pkg in packages_cran) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg)
    library(pkg, character.only = TRUE)
  }
}