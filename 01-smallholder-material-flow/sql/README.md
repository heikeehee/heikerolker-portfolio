# SQL Analytical Layer — Project 01: Smallholder Material Flow Analysis

## Purpose

This SQL layer is the **analytical interface** to a research pipeline built in R. It does not replicate the R cleaning scripts — it builds on their outputs.

The R pipeline (`scripts/clean/*.R`, `scripts/04_build_households.R`) handles all domain logic: unit conversions, documented assumptions, codebook decoding, structural zero guards, and imputation. Those decisions are encoded in R because they require researcher judgment and must be traceable for publication.

This SQL layer answers analytical questions against the clean, household-level output (`households.parquet`). It is designed to be queryable by any team member without running the R pipeline.

**Engine:** DuckDB (all queries tested against `households.parquet` via `read_parquet()`). Minor syntax adjustments needed for PostgreSQL or BigQuery.

------------------------------------------------------------------------

## Architecture

```         
Stage 1–2   Load + clean        → R only (domain logic)
Stage 2b    Impute              → R only (statistical decisions)
Stage 3     Build households    → R (joins) → households.parquet ← SQL reads here
Stage 4     Exclusions audit    → R + SQL (02_crop_summary.sql adds value here)
Stage 5     MFA input           → R (06_mfa_input.R) → mfa_input.parquet ← SQL reads here too
Stage 6–8   MFA + outputs       → R only
```

**Key:** `y4_hhid` is the household join key throughout. It is consistent across all sections but not unique within raw section tables — aggregation to household level is performed in R before this SQL layer is reached.

------------------------------------------------------------------------

## File Reference

### `01_household_spine.sql` — Coverage Diagnostics

**Research question:** Which sections cover which households? Where is data sparse?

Builds a household spine from `households.parquet` and profiles section coverage. Identifies households present in the spine but missing from specific sections (recall-only households, crops-only households, etc.).

**Key output:** Coverage matrix showing which households appear in which data sections. Directly supports the attrition and exclusion audit in `05_exclusions_audit.R`.

*R equivalent for spine construction:* `scripts/04_build_households.R §2`

------------------------------------------------------------------------

### `02_crop_summary.sql` — Crop Production and Destination Audit

**Research question:** How much of recorded harvest is accounted for in destination records? Where is the misalignment?

Queries household-level crop totals and destination flows, computing the unaccounted fraction (`harvest - (sold + consumed + stored + seed + feed + gifts)`). Profiles the crops–destinations misalignment flagged in the R pipeline.

**Key output:** Per-household harvest balance and unaccounted residual. Flags households where destinations exceed recorded harvest (data quality issue documented in `backlog.md`).

*R equivalent:* `scripts/clean/crops.R` + `scripts/04_build_households.R §4` (C05 dependency)

------------------------------------------------------------------------

### `03_animal_summary.sql` — Livestock and Animal Product Summaries

**Research question:** What is the distribution of livestock ownership and animal product flows across households?

Queries livestock counts by type, slaughter quantities, and animal product outputs (eggs, milk, hides). Includes structural zero guards consistent with those applied in R: households with `n_cattle = 0` are expected to have `milk_total_kg = 0`, not NULL.

**Key output:** Livestock ownership profiles and animal product flow summaries. Supports the animal component of the household material flow balance.

*R equivalent:* `scripts/clean/animals.R` + `scripts/clean/animal_products.R` + `scripts/clean/milk.R` + `scripts/04_build_households.R §3.5–3.8`

------------------------------------------------------------------------

### `04_flow_allocation.sql` — Material Flow Proportions

**Research question:** What share of each household's biomass production flows to each destination (food, feed, sold, waste)?

Computes destination proportions as a share of total household biomass output. These proportions feed directly into the Material Flow Analysis (MFA) described in the methods appendix.

**Key output:** Flow allocation ratios per household. NULL-safe division via `NULLIF` throughout — households with zero production are excluded from ratio calculations, not assigned zero ratios, to avoid distorting the distribution.

*R equivalent:* `scripts/06_mfa_input.R`

------------------------------------------------------------------------

## Design Decisions

**Why left joins, never inner joins.** Every join uses `LEFT JOIN` from `household_spine` outward. An inner join that silently drops households with missing section data would distort population-level estimates. NULL in an output column means "this household had no record in this section" — a meaningful research finding, not a data error.

**Why `NULLIF` for ratio denominators.** Division by zero in SQL returns an error or NULL depending on the engine. `NULLIF(denominator, 0)` makes the intent explicit: a household with zero harvest has no meaningful destination ratio, and NULL correctly propagates that absence downstream.

**Why `UNION` not `UNION ALL` for the spine.** The spine must contain each `y4_hhid` exactly once. `UNION ALL` would produce duplicates if a household appears in multiple sections (which is the norm), inflating all downstream counts.

**Why this is not a dbt project.** The R pipeline is the transformation layer. SQL here is an analytical and validation interface, not a data engineering pipeline. dbt would be appropriate if SQL replaced the R aggregation steps — which it does not in this project.

------------------------------------------------------------------------

## Running the Queries

From R using DuckDB:

``` r
library(duckdb)
library(DBI)

con <- dbConnect(duckdb::duckdb())

# Point DuckDB at the parquet output
dbExecute(con, "
  CREATE VIEW households AS
  SELECT * FROM read_parquet('data/processed/01/households.parquet')
")

# Run any query file
query <- readr::read_file(here::here("sql", "02_crop_summary.sql"))
dbGetQuery(con, query)

dbDisconnect(con, shutdown = TRUE)
```

From the DuckDB CLI:

``` bash
duckdb
D CREATE VIEW households AS SELECT * FROM read_parquet('data/processed/01/households.parquet');
D .read sql/02_crop_summary.sql
```

------------------------------------------------------------------------

## Relationship to R Scripts

The R scripts are the **source of truth** for all methodological decisions. Every assumption, exclusion, and flag is documented there. SQL queries here reference those decisions but do not re-implement them.

| What is documented in R | What SQL builds on top |
|------------------------------------|------------------------------------|
| Unit conversion factors (kg/litre, acres→ha) | Household-level totals already in kg and ha |
| Structural zero guards (`n_cattle = 0 → milk = 0`) | Ownership flags available as columns for filtering |
| Exclusion flags (E01–E06) | Clean records only; exclusions already applied |
| Imputed values (yield gap, animal feed) | Imputed columns present with `_imputed` suffix |
| `🚩 FLAG` assumptions | Documented in `backlog.md`; SQL queries assume they are resolved |

For full methodology, see the R scripts and `backlog.md`. For exclusion counts and profiling, see `05_exclusions_audit.R`.
