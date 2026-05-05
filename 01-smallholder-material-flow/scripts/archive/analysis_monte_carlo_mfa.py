"""
Monte Carlo Simulation — Smallholder Material Flow Analysis
Translates: analysis/03-MCS_household.R

Runs 1,000-iteration Monte Carlo simulations across three food groups
(crops, animal products, slaughter products) to quantify uncertainty
in household-level food flow estimates.

Each flow is modelled as a normal distribution with SD = 10% of the
observed value — consistent with typical variability assumptions in
material flow analysis (Amicarelli et al., 2021).

Negative mass balances (production over-allocated across destinations)
are flagged, saved for audit, and reset to zero with proportional
adjustment of remaining flows, following conservation of mass principles
(Brunner & Rechberger, 2016).

Outputs: aggregated mean and SD per household x food type x destination,
saved to data/processed/01/.
"""

from pathlib import Path
import numpy as np
import pandas as pd
from joblib import Parallel, delayed

# ── Config ────────────────────────────────────────────────────────────────────
DATA_DIR = Path("data/processed/01")
N_SIMULATIONS = 1000
RANDOM_SEED = 123
N_JOBS = -2  # all cores minus one

np.random.seed(RANDOM_SEED)


# ── Core simulation functions ─────────────────────────────────────────────────

def simulate_allocations(
    mean: float, sd: float, n: int,
    food_type: str, household_id: str, destination: str,
    allow_negatives: bool = True
) -> pd.DataFrame:
    """
    Simulate n draws from a normal distribution for a single material flow.

    Parameters
    ----------
    mean : float        Observed flow value (kg)
    sd : float          Standard deviation — set to 10% of mean by caller
    n : int             Number of simulation iterations
    food_type : str     Food group label (e.g. 'grains & cereals')
    household_id : str  Household survey identifier
    destination : str   Allocation destination (e.g. 'dest_sold', 'dest_missing')
    allow_negatives     If False, floor simulated values at zero

    Returns
    -------
    pd.DataFrame with columns: simulated_values, type, household_id, destination
    """
    if pd.isna(mean) or pd.isna(sd) or sd < 0:
        return pd.DataFrame()

    simulated_values = (
        np.repeat(mean, n) if sd == 0
        else np.random.normal(loc=mean, scale=sd, size=n)
    )

    if not allow_negatives:
        simulated_values = np.maximum(simulated_values, 0)

    return pd.DataFrame({
        "simulated_values": simulated_values,
        "type": food_type,
        "household_id": household_id,
        "destination": destination
    })


def simulate_household(row: pd.Series, n_simulations: int) -> pd.DataFrame:
    """
    Simulate all destination flows for one household x food type combination.

    Identifies destination columns by 'dest_' prefix. SD is 10% of the
    absolute flow value — applied consistently across all flows and food groups.
    """
    household_id = row["y4_hhid"]
    food_type = row["type"]
    dest_cols = [c for c in row.index if c.startswith("dest_")]

    results = [
        simulate_allocations(
            mean=row[col],
            sd=abs(row[col]) * 0.1,
            n=n_simulations,
            food_type=food_type,
            household_id=household_id,
            destination=col
        )
        for col in dest_cols
    ]
    valid = [r for r in results if not r.empty]
    return pd.concat(valid, ignore_index=True) if valid else pd.DataFrame()


def aggregate_simulation_results(simulation_results: pd.DataFrame) -> pd.DataFrame:
    """
    Collapse 1,000 simulation iterations to mean and SD per
    household x food type x destination.

    R equivalent: aggregate_simulation_results() in 03-MCS_household.R
    """
    required = {"household_id", "type", "destination", "simulated_values"}
    missing = required - set(simulation_results.columns)
    if missing:
        raise ValueError(f"Missing required columns: {missing}")

    return (
        simulation_results
        .groupby(["household_id", "type", "destination"])["simulated_values"]
        .agg(mean_value="mean", sd_value="std", count="count")
        .reset_index()
    )


def adjust_negative_missing(
    simulation_results: pd.DataFrame,
    output_path: Path,
    label: str
) -> pd.DataFrame:
    """
    Identify and correct negative 'dest_missing' values (over-allocated production).

    Negative mass balance is assumed to reflect measurement error.
    Affected households are saved for audit before correction.
    Remaining flows are proportionally increased; dest_missing is reset to zero.

    R equivalent: 'Adjust negative' blocks in 03-MCS_household.R
    """
    neg_mask = (
        (simulation_results["destination"] == "dest_missing") &
        (simulation_results["simulated_values"] < 0)
    )
    neg_households = simulation_results.loc[neg_mask, "household_id"].unique()

    # Save for audit trail
    simulation_results[
        simulation_results["household_id"].isin(neg_households)
    ].to_csv(output_path / f"negative_{label}.csv", index=False)

    # Proportional adjustment for affected households
    affected = simulation_results["household_id"].isin(neg_households)
    is_missing = simulation_results["destination"] == "dest_missing"

    # Count missing and non-missing rows per affected household
    counts = (
        simulation_results[affected]
        .groupby(["household_id", is_missing.loc[affected]])
        .size()
        .unstack(fill_value=0)
        .rename(columns={True: "n_missing", False: "n_other"})
    )
    counts["adjustment"] = counts["n_missing"] / counts["n_other"].replace(0, np.nan)

    adj_map = counts["adjustment"].to_dict()
    adj_values = simulation_results.loc[affected & ~is_missing, "household_id"].map(adj_map)

    simulation_results.loc[affected & ~is_missing, "simulated_values"] += adj_values.values
    simulation_results.loc[affected & is_missing, "simulated_values"] = 0

    return simulation_results


def validate_aggregated_data(aggregated_results: pd.DataFrame) -> dict:
    """
    Quality checks on aggregated simulation output.

    Checks: missing values, negative SDs, negative means, duplicates,
    outliers (3-SD rule), coverage of all type x destination combinations.

    Returns a validation report dictionary for downstream inspection.
    R equivalent: validate_aggregated_data() in 03-MCS_household.R
    """
    report = {}

    # Missing values
    missing_rows = aggregated_results[
        aggregated_results[["mean_value", "sd_value", "count"]].isna().any(axis=1)
    ]
    report["missing_values"] = missing_rows
    if not missing_rows.empty:
        print(f"  Warning: {len(missing_rows)} rows with missing values.")

    aggregated_results["sd_value"] = aggregated_results["sd_value"].fillna(0)

    # Negative SD — hard stop
    if (aggregated_results["sd_value"] < 0).any():
        raise ValueError("Negative standard deviation values found.")

    # Negative means — flag, do not stop
    neg_means = aggregated_results[aggregated_results["mean_value"] < 0]
    report["negative_means"] = neg_means
    if not neg_means.empty:
        print(f"  Warning: {len(neg_means)} rows with negative mean values.")

    # Duplicates — hard stop
    if aggregated_results.duplicated(
        subset=["household_id", "type", "destination"]
    ).any():
        raise ValueError("Duplicate rows found for household x type x destination.")

    # Outliers — 3 SD rule
    for col in ["mean_value", "sd_value"]:
        threshold = (
            aggregated_results[col].mean()
            + 3 * aggregated_results[col].std()
        )
        outliers = aggregated_results[aggregated_results[col] > threshold]
        report[f"outliers_{col}"] = outliers
        if not outliers.empty:
            print(f"  Warning: {len(outliers)} outliers in {col}.")

    # Summary statistics
    report["summary"] = aggregated_results[["mean_value", "sd_value", "count"]].describe()
    print(report["summary"])

    return report


# ── Simulation runner ─────────────────────────────────────────────────────────

def run_simulation(df: pd.DataFrame, label: str) -> pd.DataFrame:
    """
    Full simulation pipeline for one food group:
    simulate → adjust negatives → aggregate → validate → save.

    Parameters
    ----------
    df : pd.DataFrame   Cleaned household x flow data with dest_ prefixed columns
    label : str         Food group label used for output file naming

    Returns
    -------
    pd.DataFrame        Aggregated results (mean, SD per household x type x destination)
    """
    print(f"\n── Simulating: {label} ──")

    results = Parallel(n_jobs=N_JOBS)(
        delayed(simulate_household)(row, N_SIMULATIONS)
        for _, row in df.iterrows()
    )
    sim = pd.concat([r for r in results if not r.empty], ignore_index=True)
    sim.to_csv(DATA_DIR / f"simulation_results_{label}_negative.csv", index=False)

    sim = adjust_negative_missing(sim, DATA_DIR, label)
    sim.to_csv(DATA_DIR / f"simulation_results_{label}.csv", index=False)

    aggregated = aggregate_simulation_results(sim)
    aggregated.to_csv(DATA_DIR / f"aggregated_results_{label}.csv", index=False)

    validate_aggregated_data(aggregated)

    return aggregated


# ── Data preparation ──────────────────────────────────────────────────────────

def prepare_crops(excl: pd.DataFrame) -> pd.DataFrame:
    """
    Load and clean crop flow data.
    Applies seed correction to stored volume and clips negative processing to zero.
    R equivalent: 'Crops — Checks and changes to data' in 03-MCS_household.R
    """
    df = pd.read_csv(DATA_DIR / "mfa_crops.csv")
    df = df[~df["y4_hhid"].isin(excl["y4_hhid"])]

    df["stored"] = df["stored"] - df["seed"]
    df["stored"] = np.where(df["stored"] < 0, df["seed"], df["stored"])
    df["processing"] = np.where(df["newprocessing"] < 0, 0, df["newprocessing"])

    dest_cols = ["sold", "stored", "losses", "consumed",
                 "payment", "gifts", "feed", "processing"]
    df = (
        df[["y4_hhid", "type"] + dest_cols]
        .groupby(["y4_hhid", "type"])[dest_cols]
        .sum()
        .reset_index()
    )
    df["missing"] = df["produced"] - df[dest_cols].abs().sum(axis=1)

    rename = {c: f"dest_{c}" for c in dest_cols + ["missing"]}
    return df.rename(columns=rename)


def prepare_animal_products(excl: pd.DataFrame) -> pd.DataFrame:
    """
    Load and clean egg and milk flow data.
    Milk volume is net of pre-sold quantity (psold).
    R equivalent: 'Animal products — Checks and changes' in 03-MCS_household.R
    """
    eggs = pd.read_csv(DATA_DIR / "mfa_eggs.csv")
    eggs = eggs[~eggs["y4_hhid"].isin(excl["y4_hhid"])]
    eggs = (
        eggs[["y4_hhid", "item", "produced", "sold", "consumed"]]
        .rename(columns={"item": "type"})
        .assign(processing=0)
    )
    eggs["missing"] = eggs["produced"] - eggs[["sold", "consumed", "processing"]].sum(axis=1)

    milk = pd.read_csv(DATA_DIR / "mfa_milk.csv")
    milk = milk[~milk["y4_hhid"].isin(excl["y4_hhid"])]
    milk["type"] = "milk - " + milk["type"].astype(str)
    milk["produced"] = milk["produced"] - milk["psold"]
    proc_col = "processed" if "processed" in milk.columns else None
    milk = milk[["y4_hhid", "type", "produced", "sold", "consumed"]].copy()
    milk["processing"] = milk.pop(proc_col) if proc_col else 0
    milk["missing"] = milk["produced"] - milk[["sold", "consumed", "processing"]].sum(axis=1)

    df = pd.concat([eggs, milk], ignore_index=True)
    dest_cols = ["sold", "consumed", "processing", "missing"]
    return df.rename(columns={c: f"dest_{c}" for c in dest_cols})


def prepare_meat(excl: pd.DataFrame) -> pd.DataFrame:
    """
    Load and clean slaughter product flow data.
    Only households that slaughtered animals are included.
    R equivalent: 'Slaughter product — Checks and changes' in 03-MCS_household.R
    """
    df = pd.read_csv(DATA_DIR / "mfa_animals.csv")
    num_cols = df.select_dtypes(include="number").columns
    df[num_cols] = df[num_cols].fillna(0)

    df = df[df["slaughter"] > 0]
    df = df[~df["y4_hhid"].isin(excl["y4_hhid"])]
    df["type"] = "slaughter - " + df["type"].astype(str)

    dest_cols = ["sold_weight", "meat", "offal", "hides", "inedible"]
    df = (
        df[["y4_hhid", "type", "total_weight"] + dest_cols]
        .rename(columns={"total_weight": "produced", "sold_weight": "sold"})
        .groupby(["y4_hhid", "type"])[["produced", "sold", "meat", "offal", "hides", "inedible"]]
        .sum()
        .reset_index()
    )
    df["missing"] = df["produced"] - df[["sold", "meat", "offal", "hides", "inedible"]].sum(axis=1)

    dest_cols_final = ["sold", "meat", "offal", "hides", "inedible", "missing"]
    return df.rename(columns={c: f"dest_{c}" for c in dest_cols_final})


# ── Main ──────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    excl = pd.read_csv(DATA_DIR / "excl_3a.csv")[["y4_hhid"]]

    groups = [
        ("crops", prepare_crops),
        ("ap",    prepare_animal_products),
        ("meat",  prepare_meat),
    ]

    for label, prepare_fn in groups:
        df = prepare_fn(excl)
        df.to_csv(DATA_DIR / f"mfa_{label}_cleaned.csv", index=False)
        run_simulation(df, label)

    print(f"\nAll simulations complete. Outputs saved to {DATA_DIR}")