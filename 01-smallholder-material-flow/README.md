# 01 — Smallholder Resource Flow Analysis

**Tracking how agricultural production moves through smallholder households in Tanzania, from harvest to consumption**

## Overview

This project maps household-level food and biomass flows using Tanzania National Panel Survey data from the World Bank LSMS-ISA programme. It shows crop and animal production, processing, storage, processing, loss and consumption transformed into a clear, auditable material-flow picture.

The project is designed to be useful for food security, agricultural development, and sustainability analysis. It makes uncertainty explicit through probabilistic modelling, to improve decision-making.

This is the first project in my portfolio and the third Chapter of my PhD thesis entitled *Understanding Food Waste: A Systems Approach to Evidence, Uncertainty, and Action*. I successfully defended my thesis in November 2025 at the University of Bristol.

## My approach

I build from reproducible code and documented assumptions, so that every major step can be checked and repeated. I keep data issues visible rather than silently fixing them, which is why flags, exclusions, and imputation rules are tracked separately.

I write with both technical and non-technical audiences in mind. The goal is to keep the analysis defensible enough for research, but readable enough for a policy, sustainability, or data manager audience.

## Data

The analysis uses the **LSMS-ISA Tanzania National Panel Survey** household dataset.

-   Source: World Bank LSMS-ISA programme.
-   Raw data is not stored in this repository.
-   Setup and download instructions are in `data/README.md`.

## What this project does

The pipeline:

-   builds a reproducible household-level dataset from raw survey modules,
-   standardises and audits crop, livestock, and household flow information,
-   prepares MFA inputs,
-   runs Monte Carlo simulation to show uncertainty ranges,
-   and generates flow outputs suitable for reporting and visualisation.

## Analytical approach

This project uses **Material Flow Analysis (MFA)** to trace agricultural commodities through the household system. Instead of treating outputs as fixed, single numbers, it uses probabilistic uncertainty modelling to reflect the fact that many conversion factors and allocation rules come from ranges or literature values and to account for reporting bias.

That means the project is not just estimating totals. It is also showing where the data is strong, where it is uncertain, and which assumptions drive the results.

## Current status

**Core pipeline complete and reproducible.** The R workflow is documented and runs end to end.

Ongoing work includes:

-   reviewing and revising imputation logic,

-   adding SQL audit queries on clean outputs,

-   and finalising translated Python steps for selected analytical components.

See `backlog.md` and `FLAGS_REVIEW.md` for limitations, assumptions, and planned improvements.

## Key outputs

-   Household-level food availability estimates by commodity.
-   Flow summaries showing production, processing, losses, and consumption.
-   Uncertainty ranges from Monte Carlo simulation.
-   Sankey-style visualisations of household resource flows.
-   Summary tables for policy, programme, or sustainability reporting.

## Tools

-   **R** — primary pipeline, cleaning, imputation, MFA, and simulation.
-   **SQL** — audit and summary queries on clean outputs.
-   **Python** — selected analytical translation for portfolio demonstration.

## Reproducibility

Run `00_run_pipeline.R` to reproduce the main outputs.

Generated tables and figures are written to `outputs/`.\
Interactive Sankey outputs are available via the project visuals link.

## Method notes

Copilot was used for structural refactoring and code organisation. The analytical decisions, assumptions, flag classifications, and exclusion/imputation logic are documented in the repository and remain my own.

## Related projects

This project provides the production-side data used in: - `02-survey-harmonisation` — links production and consumption survey instruments. - `03-food-system-segmentation` — uses outputs to classify household food-system types.

## Why this project matters

Food security and sustainability questions often depend on data that is messy, incomplete, and inconsistent across survey modules. This project shows how I handle that reality: by keeping the pipeline reproducible, surfacing assumptions openly, and making uncertainty visible instead of hiding it. Furthermore, these data relate to Tanzania yet food supply chains are global, the projects published here show how I construct messy data into a coherent picture for sustainability reporting.
