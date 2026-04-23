# Data — 04 Plate Waste Impact Analysis

Data files are **not stored in this repository**.

---

## Source

**UK plate waste study**

This project uses data from a UK-based observational study in which food served and food remaining on the plate were weighed by meal component and food group across a sample of meals. This dataset is not publicly available via an open data portal in the same way as the LSMS-ISA data.

For information about data access, please contact the project owner directly.

---

## Setup Instructions

1. Obtain the plate waste data files as described above.
2. Place the files into the `data/raw/` folder within this project directory.
3. Do not rename the files — the cleaning scripts reference original file names explicitly and will break if names are changed.

Once raw files are in place, run the scripts in order (see `scripts/`) to reproduce the processed outputs.

---

## Notes

- The `data/raw/` and `data/processed/` folders are excluded from version control via `.gitignore` to prevent accidental upload of large or sensitive files.
- `.gitkeep` files are used to preserve the folder structure in Git without committing data.
