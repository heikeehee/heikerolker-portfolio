# =============================================================================
# 04_build_households.py
# PURPOSE: Demonstrate household-level aggregation and section joining in Python
# R EQUIVALENT: scripts/04_build_households.R
# Assumptions and data quality flags: see R equivalent and backlog.md
# Portfolio translation only — R is the source of truth
# =============================================================================

import pandas as pd

def build_spine(section_dfs: list[pd.DataFrame]) -> pd.DataFrame:
    """
    Build household spine from union of all y4_hhid values.
    R equivalent: full_join / reduce to build spine in 04_build_households.R
    All joins are left joins from spine outward — never inner joins.
    """
    all_ids = pd.concat([df[["y4_hhid"]] for df in section_dfs]).drop_duplicates()
    return all_ids.reset_index(drop=True)


def left_join_section(spine: pd.DataFrame,
                       section: pd.DataFrame,
                       on: str = "y4_hhid") -> pd.DataFrame:
    """
    Left join a section onto the household spine.
    Unmatched households retain NaN — never dropped.
    R equivalent: left_join(spine, section, by = "y4_hhid")
    """
    merged = spine.merge(section, on=on, how="left")
    n_unmatched = merged[section.columns[1]].isna().sum()
    print(f"  Unmatched households after joining {section.columns.tolist()}: {n_unmatched}")
    return merged


def profile_mismatches(df_a: pd.DataFrame,
                        df_b: pd.DataFrame,
                        keys: list[str]) -> pd.DataFrame:
    """
    Anti-join equivalent: rows in df_a with no match in df_b.
    R equivalent: anti_join(df_a, df_b, by = keys)
    Used to profile crops-destinations misalignment.
    """
    merged = df_a.merge(df_b[keys].drop_duplicates(), on=keys, how="left", indicator=True)
    return merged[merged["_merge"] == "left_only"].drop(columns="_merge")


if __name__ == "__main__":
    print("Household build functions defined.")
