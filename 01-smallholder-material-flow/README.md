# 01 — Smallholder Resource Flow Analysis

**Tracking agricultural production through to household consumption using Tanzania national survey data**

---

## Business Relevance

Understanding how food moves from farm to household — and where losses occur along the way — is a core question for organisations working in food security, agricultural development, and supply chain sustainability. This type of resource flow analysis provides a transparent, auditable account of material flows at population scale, and supports evidence-based decision-making for programme design, procurement planning, and impact measurement. The probabilistic approach makes uncertainty explicit rather than hidden, which is increasingly expected in policy-facing and ESG-relevant reporting.

---

## Data Sources

Data is sourced from the **World Bank Living Standards Measurement Study — Integrated Surveys on Agriculture (LSMS-ISA)**, Tanzania National Panel Survey (TNPS). This is a publicly available household panel dataset covering agricultural production, consumption, and socioeconomic indicators.

- Source: [https://www.worldbank.org/en/programs/lsms/initiatives/lsms-ISA](https://www.worldbank.org/en/programs/lsms/initiatives/lsms-ISA)
- Data is **not stored in this repository** — see `data/README.md` for download and setup instructions.

---

## Analytical Approach

The analysis tracks food commodities from production (what smallholder households grow) through a series of documented flow stages — on-farm losses, storage, processing, and home consumption — to estimate net availability at household level. This approach, known in academic literature as Material Flow Analysis (MFA), is here implemented as a structured data pipeline with clearly defined inputs, transformation rules, and outputs at each stage.

Because many of the conversion factors used in this pipeline (processing yields, storage loss rates) are reported with ranges rather than single values, the analysis uses **probabilistic uncertainty modelling** (Monte Carlo simulation). This means each flow stage is run thousands of times with values drawn from realistic ranges, producing an output distribution rather than a single-point estimate. The result is an honest account of what is known and what is uncertain — a standard expectation in risk-aware reporting.

---

## Key Outputs

- Household-level estimates of food availability by commodity, with uncertainty ranges
- Flow diagrams showing movement of food through production and consumption stages
- Summary tables suitable for reporting to programme managers or policy audiences

---

## Tools Used

- **SQL** — in progress
- **R** — primary language for data cleaning, pipeline construction, and Monte Carlo simulation
- **Python** — translation in progress

---

## Project Status

**In progress.** Scripts are being restructured from original PhD analysis into a documented, reproducible pipeline.

---

## How This Builds on Other Projects

This is the first project in the sequence and provides the production-side data used in:
- `02-survey-harmonisation` — which links this production data to a separate consumption recall instrument
- `03-food-system-segmentation` — which uses outputs from both projects to classify household food system types
