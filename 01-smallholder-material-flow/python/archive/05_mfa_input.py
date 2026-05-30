# =============================================================================
# 05_mfa_input.py
# PURPOSE: Construct MFA input matrix with processing node flow structure
# R EQUIVALENT: scripts/06_mfa_input.R
# Assumptions and data quality flags: see R equivalent and backlog.md
# Portfolio translation only — R is the source of truth
# =============================================================================

import pandas as pd
import numpy as np
from pathlib import Path

DATA_DIR = Path("data/processed")

def load_mfa_input() -> tuple[pd.DataFrame, pd.DataFrame]:
    mfa_input   = pd.read_parquet(DATA_DIR / "mfa_input.parquet")
    item_groups = pd.read_csv("data/reference/item_groups.csv", na_values=["", "NA"])
    return mfa_input, item_groups


def apply_processing_node(df: pd.DataFrame,
                           extraction_rates: pd.DataFrame) -> pd.DataFrame:
    """
    Split sent_to_processing_kg into product_kg and byproduct_kg.
    R equivalent: impute/processed_crops.R

    Flow:
      harvest → ... → sent_to_processing_kg
                              ↓
                    product_kg (extraction_rate)
                    byproduct_kg (1 - extraction_rate)

    Assumption: product + byproduct = 100% of input (zero processing waste).
    Assumption: sold/consumed totals are raw flows only; processed product
                flows are tracked separately out of the processing node.
    See: scripts/impute/processed_crops.R for full assumption documentation.
    """
    df = df.merge(extraction_rates[["crop", "extraction_rate"]], on="crop", how="left")
    df["extraction_rate"] = df["extraction_rate"].fillna(1.0)  # default: 100% product
    df["product_kg"]   = df["sent_to_processing_kg"] * df["extraction_rate"]
    df["byproduct_kg"] = df["sent_to_processing_kg"] * (1 - df["extraction_rate"])
    return df


def compute_mass_balance(df: pd.DataFrame) -> pd.DataFrame:
    """
    Compute per-household mass balance gap.
    R equivalent: mass balance diagnostic in scripts/06_mfa_input.R
    """
    flow_cols = ["sold_raw_kg", "consumed_raw_kg", "stored_kg",
                 "seed_kg", "gifted_kg", "fed_raw_kg", "sent_to_processing_kg"]
    available = [c for c in flow_cols if c in df.columns]
    df["total_accounted"] = df[available].sum(axis=1)
    df["balance_gap"]     = df["harvest_kg"] - df["total_accounted"]
    df["balance_pct"]     = df["balance_gap"] / df["harvest_kg"].replace(0, np.nan)

    n_gt10 = (df["balance_pct"].abs() > 0.10).sum()
    n_gt50 = (df["balance_pct"].abs() > 0.50).sum()
    print(f"Mass balance gap >10%: {n_gt10} households")
    print(f"Mass balance gap >50%: {n_gt50} households")
    return df


if __name__ == "__main__":
    print("MFA input functions defined.")
    print("Run R pipeline first to generate parquet exports.")
