# 03 — Household Food System Segmentation

**Classifying smallholder households into distinct food system types using multivariate profiling and clustering**

---

## Business Relevance

Not all smallholder households operate the same way — some are primarily subsistence-oriented, others are more market-integrated, and others fall between. Treating them as a single group leads to poorly targeted interventions and inaccurate impact assessments. This project identifies distinct household food system types from the data, providing a segmentation framework that can inform programme design, targeting criteria, and monitoring indicators. The approach is directly analogous to customer or beneficiary segmentation used in commercial and development contexts, and the outputs are presented in a format accessible to a non-technical programme or policy audience.

---

## Data Sources

Data is sourced from the **World Bank LSMS-ISA** Tanzania National Panel Survey (TNPS), drawing on variables derived in projects 01 and 02 (production flows, harmonised consumption estimates, and household characteristics).

- Source: [https://www.worldbank.org/en/programs/lsms/initiatives/lsms-ISA](https://www.worldbank.org/en/programs/lsms/initiatives/lsms-ISA)
- Data is **not stored in this repository** — see `data/README.md` for download and setup instructions.

---

## Analytical Approach

The analysis combines production-side and consumption-side variables into a single analytical dataset, then applies a two-stage approach:

1. **Multivariate profiling** (Multiple Factor Analysis) — a dimensionality reduction technique that handles mixed variable types (continuous production quantities, categorical food group indicators) and identifies the main axes of variation across households. This stage surfaces the underlying structure in the data without pre-imposing categories.

2. **Hierarchical clustering** — applied to the factor scores from stage one, this groups households into a small number of coherent types based on their overall food system profile. The number of clusters is chosen based on interpretability and internal validation metrics, and each cluster is profiled against the full variable set to produce a plain-language description.

---

## Key Outputs

- A typology of household food system types (3–5 segments), each with a descriptive profile
- Cluster membership assigned at household level for use in downstream analysis
- Summary visualisations suitable for presentation to programme managers or policy audiences

---

## Tools Used

- **R** — primary language for factor analysis and clustering
- **Python** — translation in progress
- **SQL** — in progress

---

## Project Status

**In progress.** Scripts are being restructured from original PhD analysis into a documented, reproducible pipeline.

---

## How This Builds on Other Projects

This project depends on outputs from both `01-smallholder-material-flow` and `02-survey-harmonisation`. It is the integrating analysis of the Tanzania data strand and produces segmentation outputs that can be used for targeting, monitoring, or further modelling.
