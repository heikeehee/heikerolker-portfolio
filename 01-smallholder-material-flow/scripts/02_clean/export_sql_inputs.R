# =============================================================================
# STAGE 3: Export clean R outputs for SQL audit scripts
# PURPOSE: Read canonical clean .rds outputs and write SQL-friendly CSV files
# NOTE: This script does not clean, impute, or modify values. It only exports.
# =============================================================================

source(here::here("01-smallholder-material-flow", "scripts", "packages.R"))

sql_input_dir <- here::here("data", "processed", "01", "sql_input")
dir.create(sql_input_dir, showWarnings = FALSE, recursive = TRUE)

export_rds_to_csv <- function(input_name, output_name = input_name) {
  input_path <- here::here("data", "processed", "01", "clean", paste0(input_name, ".rds"))
  output_path <- here::here("data", "processed", "01", "sql_input", paste0(output_name, ".csv"))
  
  if (!file.exists(input_path)) {
    stop(paste("Missing input file:", input_path))
  }
  
  obj <- readRDS(input_path)
  
  if (!inherits(obj, c("data.frame", "data.table", "tbl_df"))) {
    stop(paste("Object in", input_path, "is not a tabular data object."))
  }
  
  readr::write_csv(as.data.frame(obj), output_path, na = "")
  message("Exported: ", output_path)
}

# Household spine / coverage
export_rds_to_csv("household_roster")

# Recall
export_rds_to_csv("recall")

# Crop system
export_rds_to_csv("plots")
export_rds_to_csv("plot_details")
export_rds_to_csv("plots_stats")
export_rds_to_csv("crops")
export_rds_to_csv("trees")
export_rds_to_csv("pc")
export_rds_to_csv("pt")
export_rds_to_csv("prelost")
export_rds_to_csv("crops_prelost")
export_rds_to_csv("crop_disp")
export_rds_to_csv("tree_disp")
export_rds_to_csv("ag_produce")

# Animal system
export_rds_to_csv("animals")
export_rds_to_csv("animals_fin")
export_rds_to_csv("feed")
export_rds_to_csv("feed_short")
export_rds_to_csv("fishes")
export_rds_to_csv("wa")
export_rds_to_csv("produce")
export_rds_to_csv("hides")
export_rds_to_csv("mass_eggs")
export_rds_to_csv("mass_hides_long")
export_rds_to_csv("mass_hides")
export_rds_to_csv("mass_milk")
export_rds_to_csv("mass_milk_final")
export_rds_to_csv("milk")

message("Stage 3 export complete: clean R outputs written to data/processed/01/sql_input/")