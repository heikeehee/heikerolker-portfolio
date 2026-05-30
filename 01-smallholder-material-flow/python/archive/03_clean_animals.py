# =============================================================================
# 03_clean_animals.py
# PURPOSE: Demonstrate animal, animal products and milk cleaning in Python
# R EQUIVALENT: scripts/clean/animals.R + animal_products.R + milk.R
# Assumptions and data quality flags: see R equivalent and backlog.md
# Portfolio translation only — R is the source of truth
# =============================================================================

import pandas as pd
import numpy as np

MILK_KG_PER_LITRE = 1.03  # fresh whole milk density
# Assumption source: FAO Food Balance Sheet conventions
# Flag: confirm against LSMS-ISA codebook — see scripts/clean/milk.R

def convert_milk_litres_to_kg(df: pd.DataFrame,
                               litre_cols: list[str]) -> pd.DataFrame:
    """Convert milk volume columns from litres to kg."""
    for col in litre_cols:
        df[f"{col}_kg"] = df[col] * MILK_KG_PER_LITRE
    return df


def structural_zero_guard(df: pd.DataFrame,
                           ownership_flag: str,
                           quantity_cols: list[str]) -> pd.DataFrame:
    """
    Apply structural zero: if household does not own animals,
    set quantity to 0 (not NaN).
    R equivalent: case_when() pattern in 04_build_households.R
    """
    mask = df[ownership_flag] == False
    df.loc[mask, quantity_cols] = 0
    return df


if __name__ == "__main__":
    print("Animal cleaning functions defined.")
