# 02 — Survey Harmonisation

**Producing comparable household consumption estimates from two survey instruments with different recall periods**

---

## Business Relevance

Survey data from different collection instruments rarely align out of the box. Differences in recall periods, unit conventions, and food category definitions create gaps that, if ignored, produce misleading comparisons. This project addresses a practical data integration challenge — linking agricultural production recall data (12-month) to household consumption recall data (7-day) — using a statistically rigorous method that produces comparable estimates while quantifying the uncertainty introduced by the mismatch. This kind of harmonisation work is directly relevant to organisations managing multiple data streams, running longitudinal studies, or reporting against frameworks that require consistent household-level indicators.

---

## Data Sources

Data is sourced from the **World Bank LSMS-ISA** Tanzania National Panel Survey (TNPS), specifically the agricultural production and household consumption modules, which use different recall periods.

- Source: [https://www.worldbank.org/en/programs/lsms/initiatives/lsms-ISA](https://www.worldbank.org/en/programs/lsms/initiatives/lsms-ISA)
- Data is **not stored in this repository** — see `data/README.md` for download and setup instructions.

---

## Analytical Approach

The two survey instruments record the same households using different time windows: agricultural production is recalled over a 12-month period, while consumption is recorded over a 7-day recall. Directly dividing annual production by 52 to get a weekly equivalent introduces bias, because production and consumption are not evenly distributed across the year.

To reconcile this, the analysis uses **bootstrapping** — a resampling technique that repeatedly draws from the observed data to estimate the likely range of weekly consumption equivalents consistent with the annual production figures. This produces harmonised estimates that can be used alongside the consumption recall data without assuming uniform distribution. The method is transparent and reproducible, and the uncertainty introduced by the harmonisation step is carried forward explicitly.

---

## Key Outputs

- Harmonised household-level consumption estimates, annualised from 7-day recall data and made comparable with 12-month production recall
- Confidence intervals on harmonised estimates reflecting recall-period uncertainty
- Documented decision log for unit conversion and food category alignment

---

## Tools Used

- **R** — primary language for harmonisation and bootstrapping
- **Python** — translation in progress
- **SQL** — in progress

---

## Project Status

**In progress.** Scripts are being restructured from original PhD analysis into a documented, reproducible pipeline.

---

## How This Builds on Other Projects

This project depends on outputs from `01-smallholder-material-flow` (production-side data). Harmonised outputs feed into `03-food-system-segmentation`.
