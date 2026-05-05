# =============================================================================
# 01_load_data.py
# PURPOSE: Load processed datasets produced by R pipeline
# R EQUIVALENT: scripts/01_load_raw.R + scripts/04_build_households.R outputs
# Assumptions and data quality flags: see R equivalent and backlog.md
# Portfolio translation only — R is the source of truth
# =============================================================================

import pandas as pd
import pyarrow
from pathlib import Path

# Paths — adjust DATA_DIR to point to your processed data folder
# R equivalent: scripts/01_load_raw.R + scripts/04_build_households.R outputs
DATA_DIR = Path("data/processed")

def load_households():
    """Load household-level processed dataset produced by R pipeline."""
    path = DATA_DIR / "households.rds"
    # RDS files require pyreadr — install if needed: pip install pyreadr
    # Alternative: export from R as parquet or CSV for Python use
    # Recommended: add saveRDS + arrow::write_parquet() to 04_build_households.R
    raise NotImplementedError(
        "Export households.rds as parquet from R first:\n"
        "  arrow::write_parquet(households, 'data/processed/households.parquet')"
    )

def load_mfa_input():
    """Load MFA input matrix produced by 06_mfa_input.R."""
    return pd.read_parquet(DATA_DIR / "mfa_input.parquet")

def load_item_groups():
    """Load food item classification reference."""
    return pd.read_csv("data/reference/item_groups.csv", na_values=["", "NA"])

if __name__ == "__main__":
    groups = load_item_groups()
    print(f"Item groups loaded: {len(groups)} items, "
          f"{groups['classified'].sum()} classified")
