# Data — 01 Smallholder Resource Flow Analysis

Data files are **not stored in this repository**.

---

## Source

**World Bank Living Standards Measurement Study — Integrated Surveys on Agriculture (LSMS-ISA)**
Tanzania National Panel Survey (TNPS)

- URL: [https://www.worldbank.org/en/programs/lsms/initiatives/lsms-ISA](https://www.worldbank.org/en/programs/lsms/initiatives/lsms-ISA)
- Access: Publicly available via the World Bank Microdata Library. Registration is required to download.

---

## Setup Instructions

1. Navigate to the URL above and register for access if you have not already done so.
2. Download the relevant Tanzania NPS wave(s).
3. Place the downloaded files into the `data/raw/` folder within this project directory.
4. Do not rename the files — the cleaning scripts reference original file names explicitly and will break if names are changed.

Once raw files are in place, run the scripts in order (see `scripts/`) to reproduce the processed outputs.

---

## Notes

- The `data/raw/` and `data/processed/` folders are excluded from version control via `.gitignore` to prevent accidental upload of large or sensitive files.
- `.gitkeep` files are used to preserve the folder structure in Git without committing data.
