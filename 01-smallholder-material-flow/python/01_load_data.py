# =============================================================================
# 01_load_data.py
# PURPOSE: Load processed datasets produced by R pipeline
# R EQUIVALENT: scripts/01_load_raw.R + scripts/04_build_households.R outputs
# Assumptions and data quality flags: see R equivalent and backlog.md
# Portfolio translation only — R is the source of truth
# =============================================================================

import pandas as pd
import pyarrow  # noqa: F401 — required by pandas parquet backend
from pathlib import Path

# -----------------------------------------------------------------------------
# Paths
# __file__ = .../heikerolker-portfolio/01-smallholder-material-flow/python/01_load_data.py
# parents[0] = .../python/
# parents[1] = .../01-smallholder-material-flow/
# parents[2] = .../heikerolker-portfolio/   ← repo root, where data/ lives
# -----------------------------------------------------------------------------
PROJECT_ROOT = Path(__file__).resolve().parents[2]
DATA_DIR     = PROJECT_ROOT / "data" / "processed" / "01"
REF_DIR      = PROJECT_ROOT / "data" / "reference"


def load_households():
    """
    Load household-level dataset produced by 04_build_households.R.
    Requires households.parquet — export from R with:
      arrow::write_parquet(households, here::here("data","processed","01","households.parquet"))
    """
    return pd.read_parquet(DATA_DIR / "households.parquet")


def load_mfa_input():
    """
    Load MFA input matrix produced by 06_mfa_input.R.
    Requires mfa_input.parquet — export from R with:
      arrow::write_parquet(mfa_input, here::here("data","processed","01","mfa_input.parquet"))
    """
    return pd.read_parquet(DATA_DIR / "mfa_input.parquet")


def load_item_groups():
    """Load food item classification reference table."""
    return pd.read_csv(REF_DIR / "item_groups.csv", na_values=["", "NA"])


if __name__ == "__main__":
    # Sanity check — print resolved paths before loading
    print(f"PROJECT_ROOT : {PROJECT_ROOT}")
    print(f"DATA_DIR     : {DATA_DIR}")
    print(f"DATA_DIR exists: {DATA_DIR.exists()}")
    print()

    groups = load_item_groups()
    print(f"Item groups loaded: {len(groups)} rows, "
          f"columns: {list(groups.columns)}")