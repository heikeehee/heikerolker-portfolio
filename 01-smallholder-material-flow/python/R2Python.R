# R to Python
install.packages("arrow")
library(arrow)

# households
households <- readRDS(here::here("data", "processed", "01","households.rds"))
arrow::write_parquet(households, here::here("data", "processed", "01", "households.parquet"))

# mfa_input
mfa_input <- readRDS(here::here("data", "processed", "01", "mfa_input.rds"))
arrow::write_parquet(mfa_input, here::here("data", "processed", "01", "mfa_input.parquet"))