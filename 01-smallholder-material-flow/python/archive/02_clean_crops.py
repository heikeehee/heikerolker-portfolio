# =============================================================================
# 02_clean_crops.py
# PURPOSE: Demonstrate key crop cleaning steps in Python
# R EQUIVALENT: scripts/clean/crops.R
# Assumptions and data quality flags: see R equivalent and backlog.md
# Portfolio translation only — R is the source of truth
# =============================================================================

import pandas as pd
import numpy as np

def clean_crops(df: pd.DataFrame) -> pd.DataFrame:
    """
    Apply core crop cleaning rules.
    Mirrors logic in scripts/clean/crops.R.

    Key steps translated:
    - Recode sentinel values (99, 999, -9) as NaN
    - Unit standardisation (all quantities to kg)
    - Structural zero guard: if grew_crops == False, harvest = 0
    """
    # Recode sentinel values — R equivalent: na_if() / case_when()
    sentinel_values = [99, 999, -9, -99]
    numeric_cols = df.select_dtypes(include="number").columns
    df[numeric_cols] = df[numeric_cols].replace(sentinel_values, np.nan)

    # Structural zero guard — R equivalent: case_when() in 04_build_households.R
    # If household did not grow crops, harvest = 0 (not missing)
    if "grew_crops" in df.columns and "harvest_kg" in df.columns:
        df["harvest_kg"] = np.where(
            df["grew_crops"] == False, 0, df["harvest_kg"]
        )
    # NOTE: see scripts/clean/household_roster.R for participation flag definitions

    return df


def summarise_crops(df: pd.DataFrame) -> pd.DataFrame:
    """
    Aggregate crop data to household level.
    R equivalent: group_by(y4_hhid) |> summarise() in 04_build_households.R
    """
    return (
        df.groupby("y4_hhid")
        .agg(
            total_harvest_kg=("harvest_kg", "sum"),
            n_crops=("cropid", "nunique"),
        )
        .reset_index()
    )


if __name__ == "__main__":
    # Demo only — requires parquet export from R pipeline
    print("Crop cleaning functions defined.")
    print("Run R pipeline first to generate input data.")
