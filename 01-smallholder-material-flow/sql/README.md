# SQL Translation — Project 01

Portfolio demonstration of key data wrangling steps in SQL.
R scripts are the source of truth — see scripts/ for full methodology.
Assumptions and flags: see R equivalent scripts and backlog.md.

## Mapping to R scripts
| SQL file | R equivalent |
|---|---|
| 01_household_spine.sql | scripts/04_build_households.R — spine construction |
| 02_crop_summary.sql | scripts/clean/crops.R + 04_build_households.R — crop aggregation |
| 03_animal_summary.sql | scripts/clean/animals.R + scripts/clean/animal_products.R + scripts/clean/milk.R — animal aggregation |
| 04_flow_allocation.sql | scripts/06_mfa_input.R — destination flow proportions |

## Notes
- Written for PostgreSQL syntax — minor adjustments needed for SQLite or BigQuery
- Demonstrates anti-join pattern for exclusion profiling (crops-destinations misalignment)
- y4_hhid is the household join key throughout
