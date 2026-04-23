# 04 — Plate Waste Impact Analysis

**Quantifying food waste by meal component and translating losses into nutrient and carbon footprint equivalents**

---

## Business Relevance

Food waste measurement is no longer just an operational concern — it sits at the intersection of ESG reporting, regulatory compliance, and cost reduction. Frameworks such as the **Courtauld Commitment** and guidance from **WRAP** require organisations in the food sector to measure and report waste with increasing granularity. Translating waste quantities into nutrient losses and embedded carbon emissions creates a richer evidence base for internal reporting, supplier engagement, and public commitments.

This project provides a reproducible measurement and calculation pipeline that could be adapted to institutional catering, retail food service, or supply chain monitoring contexts. The outputs are structured for reporting audiences as well as analytical ones.

---

## Data Sources

Data is sourced from a **UK plate waste study**, in which food served and food left on the plate were weighed by meal component and food group across a sample of meals.

- This is not a publicly available dataset in the same way as the LSMS-ISA data. See `data/README.md` for further detail on data access and file placement.
- Data is **not stored in this repository**.

---

## Analytical Approach

The analysis proceeds in three stages:

1. **Waste quantification** — calculating waste rates by meal component (starter, main, side, dessert) and food group, expressed as weight and as a proportion of food served. Results are disaggregated to identify where the largest waste volumes and rates occur.

2. **Nutrient loss translation** — linking waste quantities to nutritional composition data (energy, protein, key micronutrients) to estimate the nutrient content of wasted food. This framing is relevant to nutrition-sensitive procurement and food security reporting.

3. **Carbon footprint translation** — applying food-specific carbon emission factors (kg CO₂-equivalent per kg of food) to waste quantities to estimate the embedded emissions in discarded food. This output is directly relevant to Scope 3 emissions reporting and organisational sustainability targets.

---

## Key Outputs

- Waste rate estimates by meal component and food group, with summary statistics
- Nutrient loss estimates linked to waste quantities
- Carbon footprint equivalents for food discarded across the study sample
- Visualisations suitable for ESG reporting, internal dashboards, or public-facing summaries

---

## Tools Used

- **R** — primary language for data cleaning, waste calculation, and output generation
- **Tableau Public** — visualisation of waste patterns and impact metrics
- **Python** — translation in progress
- **SQL** — in progress

---

## Project Status

**In progress.** Scripts are being restructured from original PhD analysis into a documented, reproducible pipeline.

---

## How This Builds on Other Projects

This project is analytically independent of the Tanzania strand (projects 01–03) and uses a separate UK dataset. It shares the same pipeline structure and output conventions as the other projects, making it straightforward to compare approaches across contexts.
