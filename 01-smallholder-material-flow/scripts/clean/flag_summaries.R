source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))

read_flag_summary <- function(path) {
  x <- readr::read_csv(path, show_col_types = FALSE)
  x$n <- suppressWarnings(as.numeric(x$n))
  x$source_file <- basename(path)
  x$stage <- ifelse(grepl("/clean/", path), "clean", "impute")
  x$script <- sub("_flag_summary\\.csv$", ".R", basename(path))
  x
}

clean_files <- list.files(
  here::here("data", "processed", "01", "clean"),
  pattern = "_flag_summary\\.csv$",
  full.names = TRUE
)

impute_files <- list.files(
  here::here("data", "processed", "01", "impute"),
  pattern = "_flag_summary\\.csv$",
  full.names = TRUE
)

all_flag_summaries <- dplyr::bind_rows(
  lapply(clean_files, read_flag_summary),
  lapply(impute_files, read_flag_summary)
)

readr::write_csv(
  all_flag_summaries,
  here::here("data", "processed", "01", "FLAGS_REVIEW_compiled.csv")
)