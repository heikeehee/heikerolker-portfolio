# Python Translation — Project 01

Portfolio translation of selected analytical steps from the R pipeline.
The R scripts remain the source of truth for methodology, assumptions, flags, imputation rules, and final analytical outputs.
See `scripts/` for the documented R pipeline, `FLAGS_REVIEW.md` for the review register, and `backlog.md` for known limitations.

## Role of Python in this project

Python is a **secondary portfolio layer**, not the canonical analysis pipeline.
Its purpose is to show translation of core analytical logic into industry-standard Python workflows after the R pipeline is stable.

The current project workflow is:

1. **R — clean scripts**: survey-specific cleaning, diagnostics, and flag generation
2. **SQL — audit on clean outputs**: queryable checks on coverage, linkage, missingness, and flow consistency
3. **R — imputation**: value-changing repair rules, allocations, unit conversions, and structural-zero handling
4. **R — MFA and uncertainty**: Multiple Factor Analysis, Monte Carlo simulation, and core analytical outputs
5. **R — Sankey outputs**: material flow visualisation aligned with the final MFA-ready dataset
6. **Python — translation layer**: selected analytical steps reproduced in Python for portfolio evidence

This means Python should be read as a parallel implementation of selected steps, not as the main production workflow.

## Mapping to R scripts

| Python file | R equivalent |
|---|---|
| `01_load_data.py` | `scripts/01_load_raw.R` |
| `02_clean_crops.py` | `scripts/clean/crops.R` |
| `03_clean_animals.py` | `scripts/clean/animals.R`, `scripts/clean/animal_products.R`, `scripts/clean/milk.R` |
| `04_build_households.py` | `scripts/04_build_households.R` |
| `05_mfa_input.py` | `scripts/06_mfa_input.R` |
| `06_mfa_analysis.py` | `scripts/07_mfa_analysis.R` |

## What Python does and does not cover

### Included
- Loading processed inputs for analysis
- Translating selected household-level wrangling steps
- Building MFA-ready analytical inputs
- Running a Python version of the MFA step

### Not included
- The full clean-stage review workflow
- The canonical flagging logic
- Imputation rules and repair methods
- The main Monte Carlo uncertainty workflow
- The canonical Sankey visual pipeline

Those steps remain in R because they depend on project-specific methodological decisions that are documented in the R scripts.

## Tools

- `pandas` — data wrangling
- `prince` — Multiple Factor Analysis (Python analogue to `FactoMineR`)
- `matplotlib` / `plotly` — analytical outputs

## Usage notes

- Run the R pipeline first to generate the processed files used as inputs here.
- Treat Python outputs as translation artifacts for portfolio purposes unless explicitly stated otherwise.
- If results differ between R and Python, the R implementation takes precedence until the difference is reviewed and explained.

## Why this structure

This project is intentionally split by responsibility:

- **R** handles research-grade survey logic and methodological decisions.
- **SQL** provides stakeholder-queryable audits and KPI-style summaries on clean outputs.
- **Python** demonstrates transferable implementation skills without becoming a second source of truth.

That division keeps the portfolio realistic, readable, and reproducible.