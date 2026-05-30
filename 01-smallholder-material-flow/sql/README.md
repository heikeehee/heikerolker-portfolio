# SQL Audit Layer — Project 01: Smallholder Material Flow Analysis

## Purpose

This SQL layer is the **audit and validation interface** to the Project 01 R pipeline. It does not replicate the R cleaning scripts and it does not replace the household-build logic in R.

The R pipeline remains the source of truth for domain decisions: codebook decoding, unit handling, structural-zero rules, exclusions, and any imputation or value-changing repair. The SQL layer sits on top of exported clean-stage outputs and is used to inspect table structure, household coverage, and routing mismatches across modules.

In practice, this SQL layer answers questions such as:

-   What is the natural grain of each cleaned output table?

-    Which households appear in which modules?

-   Which households are missing from modules they were expected to enter based on roster participation flags?

-   Where should follow-up audit work focus before downstream aggregation or reporting?

## Engine

Engine: **DuckDB**

Queries are written for DuckDB and run directly against CSV exports in:

`data/processed/01/sql_input/`

This keeps the SQL layer lightweight, portable, and easy to review in Git without rebuilding the full R pipeline every time a diagnostic query changes. DuckDB is a good fit because it can query flat files directly.

## Architecture

| Stage | Responsibility                                     | Tool   |
|-------|----------------------------------------------------|--------|
| 1     | Load raw survey data                               | R      |
| 2     | Clean individual survey modules                    | R      |
| 3     | Export SQL audit inputs (`sql_input/*.csv`)        | R      |
| 4     | Audit table grain, coverage, and expected presence | SQL    |
| 5     | Build household-level analytical outputs           | R      |
| 6     | MFA inputs and downstream modelling                | Python |

### Key distinction

The SQL layer currently works on **module-level clean outputs**, not just household-level outputs.

That means `y4_hhid` is the common household key across modules, but it is **not the grain of most tables**. Depending on the module, the natural grain may be: - `y4_hhid` - `y4_hhid + plotnum` - `y4_hhid + cropid + plotnum` - `y4_hhid + lvstckid` - `y4_hhid + productid` [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/152915217/e01cf9f2-8cb7-47b4-a614-c23e6b08eafc/crops.R)

This is intentional. The first SQL scripts are designed to audit how the cleaned module outputs behave **before** collapsing everything to household level.

## Current SQL files

### `01_module_grain_audit.sql`

**Business question:**\
Which outputs are household-level versus repeated-record tables, and which households are missing from modules they were expected to enter?

This script does three things:

1.  Builds `module_grain_summary` to show row counts, distinct households, and expected grain by module.
2.  Builds `household_module_presence` to show whether each household appears in key downstream modules at least once.
3.  Builds `expected_but_missing_households` to flag households that should appear in a module based on roster participation flags but do not.

This is a data-quality and routing audit, not a final analytical summary.

### `02_crop_audit.sql`

**Business question:**\
Where do crop-module records show missingness, contradiction, or coverage gaps that may affect harvest reporting?

Planned focus:

-   crop-module presence versus roster crop participation,

-   key gate and quantity fields,

-   household–plot–crop grain checks,

-   exceptions relevant to exclusions and backlog review.

### `03_animal_audit.sql`

**Business question:**\
Where do livestock and animal-product modules show routing gaps, missingness, or structural mismatches?

Planned focus: - livestock participation versus animal-module presence, - animal ownership versus milk/product module presence, - row-level grain checks for animals, milk, eggs, and hides, - follow-up targets for clean/impute review.

## Design decisions

### Why SQL reads exported clean CSVs

The goal is to audit the pipeline at the level where structure and routing problems are visible. By querying module-level clean outputs, SQL can inspect household coverage and table grain without duplicating the full R cleaning logic. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/152915217/a47f9f0c-8d95-4d1a-a71b-9dc477f5be45/animal_products.R)

### Why this is not a household-only SQL layer

A household-only SQL layer would hide many of the problems this audit is meant to surface. Repeated-record tables are expected in crop, livestock, and product modules, so the SQL layer keeps those tables at their natural grain and documents that grain explicitly. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/152915217/47e7263d-8ef1-4ea0-a2a9-e98c77ecf5de/animals.R)

### Why left joins are used from the roster outward

For household coverage checks, the roster is the spine. `LEFT JOIN` preserves all households in the roster and allows missing module presence to be interpreted as a real audit signal rather than silently dropping records. [duckdb](https://duckdb.org/docs/current/sql/query_syntax/from.html)

### Why module presence is not the same as question completeness

A household appearing in a module means it has at least one record in that table. It does **not** mean all downstream fields are populated. Completeness and gate-logic checks are handled separately in later module-specific SQL audits and in the R pipeline. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/152915217/a47f9f0c-8d95-4d1a-a71b-9dc477f5be45/animal_products.R)

## Running the queries

### From DuckDB CLI

``` sql
.read 01-smallholder-material-flow/sql/01_module_grain_audit.sql
```

### From R

``` r
library(DBI)
library(duckdb)
library(readr)
library(here)

con <- dbConnect(duckdb::duckdb())

query <- read_file(here("01-smallholder-material-flow", "sql", "01_module_grain_audit.sql"))
dbExecute(con, query)

dbDisconnect(con, shutdown = TRUE)
```

## Relationship to R scripts

The R scripts remain the **source of truth** for methodological decisions. SQL does not re-implement those decisions. It audits the outputs those decisions produce. [ppl-ai-file-upload.s3.amazonaws](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/152915217/4d7824f9-110f-4228-aae0-91ec23fcfd23/household_roster.R)

| What is handled in R | What SQL does with it |
|------------------------------------|------------------------------------|
| Codebook decoding and cleaning rules | Audits resulting module structure |
| Structural-zero logic | Checks whether expected module presence exists |
| Exclusions and anti-joins | Highlights households for review, not automatic exclusion |
| Imputation and value-changing repair | Assumes those steps remain in R |
| Household aggregation | Audits modules before and around that step |

## Scope and limits

This SQL layer is currently best suited for: - module coverage diagnostics, - table grain checks, - household-level expected-versus-observed presence checks,

It is **not yet** the final analytical layer for: - MFA household outputs, - full flow allocation, - or business-facing KPI reporting.

Those will come later, but the current priority is a robust audit layer that supports trustworthy downstream aggregation.
