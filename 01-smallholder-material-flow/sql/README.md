# SQL Audit & Query Layer — Project 01

This SQL folder is the **audit/query layer** for cleaned outputs in Project 01.

-   **R scripts are the canonical transformation pipeline** (`scripts/`).
-   SQL is used for **validation, profiling, anti-joins, and recruiter-facing querying examples**.
-   SQL here is intentionally **not** a full duplication of cleaning/imputation/MFA allocation logic.

## Scope

The SQL scripts in this folder are meant to show:

-   practical querying of cleaned module outputs,
-   coverage and grain checks,
-   mismatch detection patterns (e.g., anti-joins),
-   concise, rerunnable SQL artifacts.

## Mapping to R context

| SQL file | R context |
|----|----|
| 01_household_spine.sql | `scripts/04_build_households.R` |
| 02_crop_summary.sql | `scripts/clean/crops.R` + `scripts/04_build_households.R` |
| 03_animal_summary.sql | `scripts/clean/animals.R` + `scripts/clean/animal_products.R` + `scripts/clean/milk.R` |

## Notes

-   Primary target dialect: PostgreSQL-style SQL (minor syntax changes may be needed for DuckDB/SQLite/BigQuery).
-   Scripts should be **idempotent/rerunnable**.
-   Household key: `y4_hhid`.
