# Python Translation — Project 01

Portfolio translation of core pipeline steps from R.
R scripts are the source of truth for methodology, assumptions, and flags.
See scripts/ for full documented R pipeline and backlog.md for known limitations.

## Mapping to R scripts
| Python file | R equivalent |
|---|---|
| 01_load_data.py | scripts/01_load_raw.R |
| 02_clean_crops.py | scripts/clean/crops.R |
| 03_clean_animals.py | scripts/clean/animals.R + animal_products.R + milk.R |
| 04_build_households.py | scripts/04_build_households.R |
| 05_mfa_input.py | scripts/06_mfa_input.R |
| 06_mfa_analysis.py | scripts/07_mfa_analysis.R |

## Tools
- pandas — data wrangling
- prince — Multiple Factor Analysis (Python equivalent of FactoMineR)
- matplotlib / plotly — outputs

## Notes
- Assumptions and data quality flags are documented in R scripts only
- This translation covers core analytical steps — not the full cleaning pipeline
- Run R pipeline first to generate data/processed/ files used as inputs here
