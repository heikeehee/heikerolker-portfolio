# Session Notes — 01 Smallholder Material Flow

## Session 1 — 2026-04-23

### What we did
- Pushed all Chapter 3 scripts to the `work/ch3-material-flow` branch
- Discovered 29 files in `scripts/` (not the expected 13) — additional files came from a second machine
- Identified two overlapping pipelines from different phases of the PhD:
  - **Underscore files** (`01_`, `02_` etc.) — earlier working versions from the Chapter 3 folder
  - **Hyphen files** (`03-` prefix) — thesis-final versions, most recent and reliable
- Confirmed that `functions.R` is the master functions file (covers all chapters); `00_functions1.R` is an earlier draft kept for traceability only
- Flagged unhealthy patterns already visible from filenames alone:
  - Two naming conventions mixed in one folder
  - Duplicate functions files
  - HTML output files in the scripts folder (to be removed)
  - Ambiguous prefixes (`0x_`, `99_`, `xx_`)
  - Two weighting scripts with unclear relationship

### What I learned
- **Code audit before action** — always understand what you have before restructuring. This is standard practice in industry when inheriting or migrating a codebase.
- **How to audit a script file** — what to look for: portability of paths, clarity of dependencies, silent data changes, repeated logic that should be functions, unexplained commented-out code, output handling.
- **Human-in-the-loop division of labour** — three categories apply as we work through scripts:
  - 🧠 Review and decide (yours only — domain judgment, analytical calls)
  - 👁️ Check and verify (AI does it, you confirm it's correct — requires ability to read the code)
  - 🤖 Outsource (mechanical, repeatable — AI handles, you briefly review)
- **What learning SQL, Python and stronger R actually buys** — SQL for direct data querying; Python to expand what can be automated; stronger R to make the 👁️ category faster and more reliable (you can verify AI output more confidently)
- **What is AI-proof in your work** — analytical judgment on exclusions, imputation decisions, interpretation of cluster outputs, selection of uncertainty ranges, deciding what a result means for an audience. These are the skills to surface to employers.

### Planned for Session 2
- Read `functions.R` and `03-chap3.Rmd` directly (branch should be indexed by then)
- Go through each `03-` script: summarise what it does, flag unhealthy patterns, identify execution order
- Review underscore files for any unique logic not captured in the `03-` files
- Propose clean folder structure separating primary scripts from reference/archive
- Begin restructuring `functions.R` to portfolio standards

### Open questions (carry forward)
- Does `0x_Weighting.R` contain logic that made it into the `03-` pipeline, or is it genuinely missing?
- Which underscore files contain unique content not superseded by the `03-` versions?
- Confirm all `source()` calls point to `functions.R` not `00_functions1.R`

---

*This file is a working document — not public-facing. It lives on the working branch only and will not be merged to main.*
