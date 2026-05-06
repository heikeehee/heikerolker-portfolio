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

## Session — 2026-04-25 | Structural passes: data layout, path cleanup, branch hygiene

### Branch
`work/ch3-material-flow`

### What we did

**packages.R**
- Created `01-smallholder-material-flow/scripts/packages.R`
- Centralised package loading: `here`, `haven`, `tidyverse`, `data.table`, `ggthemes`, `ggimage`, `treemapify`, `purrr`
- Confirmed it supersedes scattered `library()` calls throughout scripts

**functions.R**
- Created cleaned `01-smallholder-material-flow/scripts/functions.R`
- Supersedes `00_functions1.R` (old file still in folder — flagged for deletion in a future pass)

**Shared data folder structure**
- Created `data/` at repo root with:
  - `data/raw/lsms/` — for LSMS-ISA `.dta` input files (gitignored)
  - `data/processed/01/`, `02/`, `03/` — for pipeline outputs per project (gitignored)
  - `data/README.md` — download instructions, reproducibility notes, data licence info
- Updated root `.gitignore` to exclude `data/raw/` and `data/processed/` and `04-plate-waste-impact/data/raw/`
- `04-plate-waste-impact/data/raw/` created separately (project-specific source)

**03-chap3.Rmd — path cleanup**
- Replaced all hardcoded file paths with `here::here()`
- `.dta` inputs → `here::here("data", "raw", "lsms", "filename.dta")`
- Processed inputs/outputs → `here::here("data", "processed", "01", "filename")`
- Added YAML header if missing
- Added setup chunk loading `here` if missing
- Flagged unhealthy patterns inline with 🚩 comments (candidates for function extraction, repeated blocks, silent data changes, commented-out code)

**Deleted empty project-level data folders**
- Removed `01-smallholder-material-flow/data/`
- Removed `02-survey-harmonisation/data/`
- Removed `03-food-system-segmentation/data/`
- These were superseded by the shared `data/` structure at repo root
- `04-plate-waste-impact/data/` retained (project-specific)

**Branch and PR hygiene**
- Cleared accumulated merged Copilot branches — branch list reduced to `main` + `work/ch3-material-flow`
- Learned: always delete Copilot branch immediately after merging PR

### What I learned

**PR workflow (now fully internalised)**
- Agent always opens a Draft PR — click "Ready for review" before merging
- Always click "Delete branch" after merging — never skip this
- Check base branch before merging — must be `work/ch3-material-flow`, not `main`
- Run agent passes one at a time — parallel passes cause conflicts

**Repo hygiene**
- Merged branches should be deleted immediately — they accumulate fast
- `main` + one working branch is the correct state between sessions
- Branch list is a signal: if it's long, something wasn't cleaned up

**here::here() — why it matters**
- Hardcoded paths break on any machine other than the one where the script was written
- `here::here()` resolves paths relative to the project root `.Rproj` file — works for any collaborator or reviewer
- `.dta` files (raw LSMS data) → `data/raw/lsms/`
- Intermediate and output files → `data/processed/01/`

**When to start a new chat**
- Start a new chat when structural work is complete and the work lives in the repo, not in the thread
- Opening prompt for next chat: paste general instructions + one sentence on current state + one sentence on what comes next

### Passes completed this session
- ✅ packages.R
- ✅ functions.R
- ✅ Shared data folder structure + .gitignore + data/README.md
- ✅ 03-chap3.Rmd — here::here() paths + 🚩 flags + YAML + setup chunk
- ✅ Deleted project-level data/ folders (01, 02, 03)

---

## TODO next

### Immediate — Pass 4 (new chat)
- [ ] Open `01-smallholder-material-flow/scripts/03-chap3.Rmd` on `work/ch3-material-flow`
- [ ] Go through each 🚩 flag — decide per flag: fix now / extract to function / convert to loop / remove commented-out code
- [ ] Start new chat with: *"Structural setup complete on work/ch3-material-flow. Working through 🚩 flags in 01-smallholder-material-flow/scripts/03-chap3.Rmd"*

### Soon — script folder cleanup (01)
- [ ] Delete `00_functions1.R` — superseded by `functions.R`
- [ ] Standardise script naming convention — choose either `-` or `_` as separator and apply consistently across all files in `scripts/`

### Later — project 01 pipeline
- [ ] Verify all scripts in `01-smallholder-material-flow/scripts/` source `packages.R` and `functions.R` correctly
- [ ] Check script execution order — document in `01-smallholder-material-flow/README.md`
- [ ] Python translation of key steps in `03-chap3.Rmd`
- [ ] SQL equivalent for data wrangling sections
- [ ] Tableau Public visualisation plan for material flow outputs

### Backlog — other projects
- [ ] Apply same structural passes (packages, functions, here::here, 🚩 flags) to 02-survey-harmonisation
- [ ] Apply same structural passes to 03-food-system-segmentation
- [ ] Apply same structural passes to 04-plate-waste-impact

---

*This file is a working document — not public-facing. It lives on the working branch only and will not be merged to main.*

# navigate to your repo (if not already there)
cd /Users/heikerolker/Documents/GitHub/heikerolker-portfolio

# check you're on the right branch
git branch

# stage a specific file
git add 01-smallholder-material-flow/scripts/packages.R

# stage everything changed in the project folder
git add 01-smallholder-material-flow/

# commit
git commit -m "..."

# push to remote
git push origin work/ch3-material-flow

clean:	Removing dead code, fixing paths
fix:	Correcting logic or broken behaviour
refactor:	Restructuring without changing behaviour
translate:	Python or SQL equivalents added
docs:	README or comment updates

Certainly! Here is a business-facing, reflective summary for your session notes.  
This is framed for your records, hiring conversations (“tell us about your pipeline refactoring project”), and for continued self-improvement as you move further into private sector data roles.

---

# 🧑‍💼 Transitioning Research Pipelines to Business Data Workflows  
### Session Notes — Major Changes, Observed Patterns, and Guidance

---

## 🚩 1. **Major Changes Made Across Scripts**

**a. Modernized Path Management**
- Switched all data/script access to `here::here()` — all file reads/writes are now project-rooted, fully portable, no absolute/fragile paths.
- Setup chunks load packages and functions via `source(here::here(...))` with a single `.Rproj` at repo root for reproducibility.

**b. Centralized Reference and Lookup Tables**
- Built a single source-of-truth for conversion factors (`food_conv`/`items_lookup.csv`) and always joined to this table for unit standardization, not to ad-hoc frames.
- Lookup tables versioned under `data/reference/`.

**c. Defensive Data Wrangling and Diagnostics**
- Added checks for missing files, explicit QA output for missing conversions, and used `stopifnot()` where silent code would previously have failed.
- Exclusions, anti-joins, and imputation steps are all flagged, commented, and optionally output to diagnostics for traceability.

**d. Function Encapsulation and Code Hygiene**
- Moved allocation logic (e.g., household-level egg flow allocation) from inline blocks into well-commented functions.
- Removed “unhealthy patterns”:
  - Duplicate/ambiguous column names after joins/binds (always renamed!)
  - Copy-paste transformation chains that should be wrapped in a function or loop
  - Commented code left in without explanation

**e. Business-Readable, Modular Output**
- Output data is always ready for Tableau or further publication (CSV/RDS), with clear, self-explanatory columns and method/audit fields.
- Variable names clarify source and logic (e.g., `allocation_method`, `hhsize`, `unallocated_kg`).

---

## 🔎 2. **Patterns Observed Across Scripts**

### *Unhealthy (now addressed or flagged):*
- **Hardcoded paths** and references to working directory structure (broke on new computer/clone).
- **Silent logic buried mid-script** (allocation, cleaning, exclusions) with no comment or explanation.
- **Column name ambiguity** after merges or binds.
- **Ad-hoc “items” or lookup tables** built on the fly with insufficient coverage for all cases.

### *Healthy (already present or now improved):*
- **Explicit anti-join exclusions** for respondent removals, with plan for “profile before exclude” going forward.
- **Use of QA logs/diagnostics** for missing conversions or unmatched merges.
- **Layered allocation/cascade logic** for reconciling survey instruments (well-mapped in consumption/production overlap).

---

## 🌳 3. **What to *Keep Doing* (Business-Ready Best Practice)**

- **Always anchor logic to survey/business variable names;** comment why/when mapping occurs for periods/IDs/etc.
- **Deduplicate columns post-join and name explicitly.**
- **Push all “magic numbers”, conversions, and crosswalks to versioned, human-readable reference files.**
- **Keep producing diagnostic outputs for new missing cases or exclusion events**—makes defensibility and reproducibility very strong in business context.
- **Document allocation, imputation, and exclusion logic in plain language within code and in README files.**

---

## ⚠️ 4. **What to *Improve/Watch Out For* Going Forward**

- **Competing columns after joins**: Always check with `colnames()` directly after a join (esp. if joining on several possible respondent IDs/periods) and trim/select/rename as needed before any mutate/summarise.
- **Type safety**: Whenever reading survey data (esp. from Stata/SAS/SAV), always coerce variables needed for arithmetic to `numeric` and QA after conversion.
- **Function boundaries**: Wrap blocks of logic (e.g., allocation, unit conversion, exclusions) into small, single-purpose functions—document use cases in a business-readable way.
- **Intermediate output hygiene**: Remove (or move to explicit diagnostics) any ad-hoc code or QA artifacts in final scripts.
- **Quantitative step logging:** Wherever mass, value, or respondent count can “leak” between stages, tabulate and compare before/after as QA for both research and business traceability.

---

## ⭐ 5. **New Strengths and Portfolio-Quality Practices (Ready for Interviews/Showcases)**

- Industry-standard file referencing, code hygiene, and pipeline structure.
- Audit trails for all cleaning/exclusion and imputation decisions—“why not just drop it?” is always explained and justified.
- Readable, non-academic framing throughout: someone in business, government, or sustainability roles can follow your process.
- End-to-end reproducibility: full pipeline can be cloned and rebuilt on any Mac; all data references resolved via `here::here()`, and all external dependencies are documented in `packages.R`.

---

## 💡 **Session Takeaways**

> Ruthless prioritization and modularization (functions, lookups, file paths) not only made my script portfolio-ready, but also highlighted the importance of clarity, reproducibility, and auditability for business data analysis.
>
> Moving forward, each script will:
> - Prioritize clarity for non-academic readers
> - Use reference tables and modular logic
> - Include diagnostics and explanatory comments as standard
> - Track exclusion/imputation events with annotated output

## The Rules — Pipeline Stage Boundaries

The core principle is simple:

> **Each stage answers one question. When the question changes, you're in a new script.**

Here are the questions, in order:

---

### Stage 0 — Load
**Question: What are the raw files and where are they?**

- Reads every raw file, nothing else
- No renaming, no filtering, no joins
- Outputs: named list of raw data frames, exactly as they came from the World Bank
- **Ends when:** every raw file is in memory. The moment you touch a value, you're in cleaning.

---

### Stage 1 — Clean (one script per survey section)
**Question: What does this section actually contain, and is it internally consistent?**

Cleaning is *mechanical*. It applies rules that follow directly from the data documentation (the LSMS-ISA codebook). No judgement required — if the codebook says code 99 means "don't know", you recode it to `NA`. That's not a decision, it's a transcription.

Cleaning includes:
- Rename variables to human-readable names
- Recode sentinel values (99, 999, -9) to `NA`
- Convert units that are unambiguous (e.g. grams → kg where the codebook specifies)
- Drop structural zeros with a comment (a plot with no area *cannot* be in the analysis — this is not a judgement call)
- One output `.rds` per section

**Ends when:** the data reflects what respondents actually reported, faithfully. You haven't yet decided what to *do* about missing values or implausible ones.

🚩 **Boundary violation signal:** If you find yourself writing `if is.na, assume X` — stop. You're in imputation territory.

🚩 **Boundary violation signal:** If you're joining two sections together — stop. You're in build-households territory.

---

### Stage 2 — Impute (one script per domain with assumptions)
**Question: Where data is missing or implausible, what is the most defensible value to substitute — and what are the assumptions behind that choice?**

Imputation is *judgemental*. It requires domain knowledge (yield distributions, regional norms, biological constraints). Every line in an imputation script that assigns a value to a previously missing cell is an assumption that needs to be visible and changeable.

Imputation includes:
- Yield gap filling (median by crop × region, or model-based)
- Animal productivity assumptions (litres/day, offtake rates)
- Explicit sensitivity bounds (low/mid/high assumption sets)

**Ends when:** every variable that will enter the household-level dataset has a value — either observed or explicitly imputed with a documented reason.

🚩 **Boundary violation signal:** If you're renaming columns or recoding sentinel values here — that's cleaning, move it back.

🚩 **Boundary violation signal:** If the imputed values are used directly in a calculation without first being saved to a processed file — the assumption is invisible. Always save imputed datasets as a distinct output.

---

### Stage 3 — Build Households
**Question: What is the one-row-per-household dataset that the analysis needs?**

This is pure joining and aggregation. No new assumptions. No filtering that hasn't already been documented in clean/ or impute/.

- Joins all section outputs (from clean/) and imputed outputs (from impute/)
- Aggregates from plot/crop/animal level to household level
- Derives composite variables (e.g. total harvest kg = sum across plots and crops)
- Produces one flat file: `households.rds`

**Ends when:** you have one row per household, all variables present, ready for analysis.

🚩 **Boundary violation signal:** If you're imputing inside this script ("oh the join produced NAs, let me just replace with 0") — stop. Go back to impute/.

🚩 **Boundary violation signal:** If you're making a *new* analytical decision (e.g. "I'll cap outliers at the 99th percentile") — that belongs in MFA input prep, not here.

---

### Stage 4 — Exclusions Audit
**Question: Who is not in the final dataset, and is that defensible?**

This is a *reporting* script, not a transformation script. It reads `households.rds` and the pre-join section files, profiles the excluded households, and outputs a table.

- Anti-joins to identify excluded households at each stage
- Compares excluded vs included on key variables (region, wealth, land size)
- Flags systematic patterns
- Produces one summary table → goes directly into your methods appendix

**This script changes nothing.** It only reports.

---

### Stage 5 — MFA Input Prep
**Question: What transformations does the analysis method require that are not about data quality?**

This is where *analytical* decisions live — decisions driven by the requirements of MFA, not by data problems:

- Destinations / flow allocation (proportioning harvest across sales, storage, consumption)
- Residue calculations
- Scaling, normalisation, or log transformation if required by MFA
- Handling of rare categories (collapse small crop groups)

**Ends when:** the input matrix for MFA is ready.

The distinction from cleaning: if you had perfect data with no missing values, you would still need this script. Cleaning exists because of data problems. MFA input prep exists because of method requirements.

---

### The Full Decision Tree

When you're writing code and you don't know where it belongs, ask:

```
Is this reading a raw file?
  → 01_load_raw.R

Is this making the data reflect what respondents reported faithfully?
  → clean/[section].R

Is this filling in a missing or implausible value using an assumption?
  → impute/[domain].R

Is this joining sections together or aggregating to household level?
  → 04_build_households.R

Is this reporting who got excluded and why?
  → 05_exclusions_audit.R

Is this transforming variables to meet the requirements of the analytical method?
  → 06_mfa_input.R

Is this running the analysis?
  → 07_mfa_analysis.R / 08_uncertainty.R

Is this producing a table or chart from results?
  → 09_outputs.R
```

---

### Applied to Your Specific Complexity

The LSMS-ISA is unusually messy, which means you'll hit edge cases. Here's how the rules handle the ones you've already named:

| Your specific problem | Rule |
|---|---|
| Milk is a different section from animal products | Correct — separate clean/ scripts. The section boundary *is* the script boundary. |
| `01b_Yield_gap` mixes cleaning and imputation | Split it. The cleaning part (rename, recode) → `clean/crops.R`. The imputation part → `impute/yield_gap.R`. |
| Destinations is its own section | Correct — `clean/destinations.R` handles section cleaning, `06_mfa_input.R` handles the flow allocation logic. |
| Cross-section dependency in cleaning (need region from HH roster to filter storage) | Allowed *only* in `04_build_households.R`. If the filter must happen earlier, document it explicitly as a cross-section dependency with a comment, and load only the one needed variable — don't re-import the full section. |
| `99_final.R` doing everything | Everything in it gets classified by the decision tree above and moved. Nothing stays in a `99_` script. |

---

The rules are simple. The discipline is in applying them consistently when the data is pushing back. When in doubt: **if it contains an assumption, it belongs in `impute/`. If it changes nothing, it belongs in `05_exclusions_audit.R`. Everything else follows the decision tree.**
