# =============================================================================
# 06_mfa_analysis.py
# PURPOSE: Run Multiple Factor Analysis on household input matrix
# R EQUIVALENT: scripts/07_mfa_analysis.R
# Assumptions and data quality flags: see R equivalent and backlog.md
# Portfolio translation only — R is the source of truth
# =============================================================================
# NOTE: Python MFA via 'prince' package — install: pip install prince
# FactoMineR (R) and prince (Python) use the same underlying SVD approach.
# Results should be comparable but not identical due to implementation differences.
# For publication, use R/FactoMineR output. Python here is for portfolio demonstration.
# =============================================================================

import pandas as pd
import prince
import matplotlib.pyplot as plt
from pathlib import Path

DATA_DIR   = Path("data/processed")
OUTPUT_DIR = Path("python/outputs")
OUTPUT_DIR.mkdir(exist_ok=True)


def run_mfa(mfa_matrix: pd.DataFrame,
            groups: list[int],
            group_names: list[str],
            n_components: int = 5) -> prince.MFA:
    """
    Run Multiple Factor Analysis.
    R equivalent: FactoMineR::MFA(mfa_matrix, group = groups, name.group = group_names)

    Parameters
    ----------
    mfa_matrix   : DataFrame without y4_hhid — numeric columns only
    groups       : list of ints — number of variables per group (matches R groups= argument)
    group_names  : list of str — group labels (matches R name.group= argument)
    n_components : number of dimensions to retain
    """
    mfa = prince.MFA(
        n_components=n_components,
        n_iter=10,
        copy=True,
        random_state=42
    )
    mfa = mfa.fit(mfa_matrix, groups=dict(zip(group_names, groups)))
    return mfa


def plot_scree(mfa: prince.MFA, output_dir: Path = OUTPUT_DIR):
    """Scree plot of explained variance — R equivalent: fviz_eig()"""
    variance = mfa.eigenvalues_summary
    fig, ax = plt.subplots(figsize=(8, 4))
    ax.bar(range(1, len(variance) + 1), variance["% of variance"])
    ax.set_xlabel("Dimension")
    ax.set_ylabel("% Variance explained")
    ax.set_title("MFA Scree Plot — Smallholder Food System")
    plt.tight_layout()
    fig.savefig(output_dir / "scree_plot.png", dpi=150)
    print(f"Saved: {output_dir / 'scree_plot.png'}")
    plt.close()


def extract_scores(mfa: prince.MFA,
                   mfa_matrix: pd.DataFrame,
                   hhids: pd.Series) -> pd.DataFrame:
    """
    Extract household factor scores with y4_hhid.
    R equivalent: mfa_res$ind$coord joined back to household data.
    y4_hhid retained for join to household characteristics (project 03).
    """
    scores = mfa.row_coordinates(mfa_matrix)
    scores.index = hhids.values
    scores.index.name = "y4_hhid"
    return scores.reset_index()


if __name__ == "__main__":
    print("MFA analysis functions defined.")
    print("Requires: mfa_input.parquet exported from R pipeline")
    print("Requires: mfa_groups.parquet or equivalent group structure")
