# Flags Review Log — Project 01

Generated after clean/ extraction pass. All items below require a decision before Stage 3 (build_households).

------------------------------------------------------------------------

## [ASSUMPTION] flags — documented in impute/ scripts

| ID | Clean script | impute/ script | Description | Value/Rule | Action needed |
|------------|------------|------------|------------|------------|------------|
| A01 | clean/recall.R | impute/recall.R | Food item unit conversion factors (litre/pieces → kg) | Product-specific density factors; source: literature / standard density references (no single URL — varies per item) | Extract entries that require imputation (unit missing, etc) |
| A02 | clean/crops.R | impute/crops.R | gps_area == 0 recoded to NA | LSMS team recommendation: zero GPS = unreliable | Confirmed with LSMS team no sensitivity run needed if guidance is firm |
| A03 | clean/crops.R | impute/crops.R | GPS preferred over farmer area estimate | plotsize = GPS where available, farmer as fallback | Confirmed against LSMS-ISA literature on area measurement bias |
| A04 | clean/crops.R | impute/crops.R | area_harvested_alt definition | area_harvested_new / area_new × plotsize | Review if farmer and GPS estimates diverge widely; check mismatch flags |
| A05 | clean/crops.R | impute/crops.R | total_harvest = harvest_remain + quant_harvest | Assumes remaining harvest will be collected, allows to determine/verify total imput | Sensitivity: run with total_harvest = quant_harvest only |
| A06 | clean/ag_produce.R | impute/ag_produce.R | Volume-to-kg density factors for processed products | Multiple litre-to-kg factors; several NA; source: <https://www.aqua-calc.com/calculate/food-volume-to-weight> (varies per item) | Source missing factors or mark as unresolvable; profile NA impact |
| A07 | clean/ag_produce.R | impute/ag_produce.R | Input allocation rules (heuristic) | Cascade of if/else rules; input/quant ratios used | No guidance from LSMS team, uncertain rows in exclusions audit |
| A08 | clean/ag_produce.R | impute/ag_produce.R | HH 3208-001 input divided by 2 | Manual fix — appears double-counted in raw | Re-verify if raw data changes |
| A09 | clean/ag_produce.R | impute/ag_produce.R | Remaining unresolved input assigned full input | Fallback: new_input = input when all rules fail | Profile \~1 affected record in exclusions audit |
| A10 | clean/animals.R | impute/animals.R | Carcass breakdown coefficients | @Hal.2020; @Alexander.2016; @Opio.2013 — literature-derived | Confirm whether EW in Alexander.2016 includes offal — double-count risk |
| A11 | clean/animals.R | impute/animals.R | Tethering replaced with secondary feed practice | feed1 = feed2 when feed1 == "tethering" & feed2 != NA | Confirm codebook definition of tethering before stage 3 |
| A12 | clean/animal_products.R | impute/animal_products.R | Hides allocation to animal type (heuristic fcase) | Piece count matched to slaughter numbers via cascading logic | Review each branch with domain expert; profile mis-classified households |
| A13 | clean/animal_products.R | impute/animal_products.R | Three HH manual hides split | 7294-001 (1.5/1.5), 8014-001 (0/5), 4764-001 (1/1) | Avoid raw data hard coded changes, flag |
| A14 | clean/animal_products.R | impute/animal_products.R | Poultry feed fractions (backyard) | @MacLeod.2013 p.107 — SSA averages | Tanzania-specific data not available; flag for sensitivity run |
| A15 | clean/animal_products.R | impute/animal_products.R | Egg laying rate 45 eggs/hen/year | @MacLeod.2013 p.105 — SSA average | Sensitivity: 30 (low) and 60 (high) eggs/hen/year |
| A16 | clean/animal_products.R | impute/animal_products.R | FCR 2.3 kg DM / kg eggs | @Alexander.2016 | Sensitivity: 1.8 (low) and 3.0 (high) per @MacLeod.2013 range |
| A17 | clean/animal_products.R | impute/animal_products.R | Egg consumption via recall data | Placeholder only — logic in archive/04_Animal_products.Rmd lines 565–671 | Implement before stage 3; add consumptionNPS4.dta to 01_load_raw.R |
| A18 | clean/milk.R | impute/milk.R | Three HH missing milk average filled by inspection | 1001-001 → lo; 1002-001 → midpoint; 2943-001 → sum of dispositions | Flag, needs imputing or exclusion |
| A19 | clean/milk.R | impute/milk.R | processed = psold when processed \< psold | Volume of processed milk (processed) not recorded only volume of processed & sold (psold) | Processing variable needs to be imputed, include in sensitivity analysis |
| A20 | clean/milk.R | impute/milk.R | SD = range / 4 | Standard approximation (range ≈ 4σ for normal distribution) | Sensitivity: compare with Beta/PERT distribution for asymmetric uncertainty |
| A21 | clean/milk.R | impute/milk.R | PERT-like weighting: 0.2 × min + 0.6 × avg + 0.2 × max | Method chosen empirically (fewest exclusions n=92 vs alternatives) | Sensitivity: use simple average = (av + hi + lo) / 3 |
| A22 | clean/milk.R | impute/milk.R | Feed fraction tables (duplicated from impute/animals.R) | @Opio.2013 p.117/p.119 — SSA averages | Consolidate into data/reference/feed_fractions.csv when stable |
| A23 | clean/milk.R | impute/milk.R | FCR 0.7 kg DM / kg milk | @Alexander.2016 — applied uniformly to all ruminants | Sensitivity: separate FCRs for large (0.8) and small (0.6) ruminants |
| A24 | clean/destinations.R | impute/destinations.R | HH 8659-001 maize consumed := 480 | Manual fix — data entry error in raw | Avoid, exclude and impute in other manner |
| A25 | clean/destinations.R | impute/destinations.R | RPR and Dry Matter from FAOSTAT | Tanzania country-level averages from FAOSTAT crop residues | Sensitivity: ±20% on RPR; check if regional FAOSTAT data available |

------------------------------------------------------------------------

## [EXCLUSION] flags — documented in 05_exclusions_audit.R

| ID | Clean script | Reason | Type | Action needed |
|-------------|---------------|-------------|-------------|------------------|
| E01 | clean/crops.R | harvest values set to 0 when harvested == "no" | structural zero \| missing data — FLAG | Profile vs included on region, land size, wealth |
| E02 | clean/crops.R | 2 records where area_planted is NA → replaced with area_harvested_new | missing data | Identify affected HH/crop; confirm replacement is valid |
| E03 | clean/crops.R | ag3b_01b == 2 filters short-season plots | plots listed for long and short season, means some are double counted and used all year long | No action |
| E04 | clean/animals.R | sentinel 0 applied when gateway question == "no" | structural zero \| missing data — FLAG | Profile proportion of zeros vs NAs; flag possible recall fatigue |
| E05 | clean/animal_products.R | hides[produced == 0] dropped | structural zero \| missing data — FLAG | Confirm all zeros correspond to zero slaughter; count records |
| E06 | clean/milk.R | non-ruminant categories dropped from milk section | structural zero | Confirm no milkable animals coded under other categories |
| E07 | clean/milk.R | physiological plausibility thresholds for milk | implausible value | Profile sensitivity to thresholds; compare excluded vs included |
| E08 | clean/destinations.R | zeros applied where sale/storage/loss gateway == "no" | structural zero \| missing data — FLAG | Profile proportion of zeros per variable and crop |
| E09 | clean/destinations.R | ±30% tolerance on disposition vs harvest | assumption | Sensitivity to threshold (20%, 30%, 40%); profile excluded by crop |
| E10 | clean/destinations.R | "crop produces no residue" records dropped |  | Survey category but plausibility doubtful |

------------------------------------------------------------------------

## [CROSS-SECTION] dependencies — retained in clean/ temporarily

| ID | Script | Dependency | Variable | Move to |
|--------------|--------------|----------------|--------------|--------------|
| C01 | clean/animals.R | breakdown.xlsx reference data | raw$ref$breakdown (loaded in 01_load_raw.R) | Reference data — no restructuring needed; confirm source in 01_load_raw.R |
| C02 | clean/animal_products.R | carcass breakdown + slaughter counts | wa.rds, animals_fin.rds from clean/animals.R | 04_build_households.R |
| C03 | clean/animal_products.R | poultry ownership + feed practices | animals_fin.rds, feed_short.rds from clean/animals.R | 04_build_households.R |
| C04 | clean/milk.R | feed practices from livestock section | feed_short.rds from clean/animals.R | 04_build_households.R |
| C05 | clean/destinations.R | crop production with area and yield | pc.rds, pt.rds from clean/crops.R | 04_build_households.R |
| C06 | clean/destinations.R | residue section depends on crop_disp.rds | crop_disp.rds | 04_build_households.R (run Section 4 after Section 3) |

------------------------------------------------------------------------

## Resolved flags (removed from code)

| Script | Was | Resolution |
|----------------------|-----------------|---------------------------------|
| All clean/ scripts | `# 🚩 FLAG [ASSUMPTION]: ...` comment blocks | Replaced with `# ASSUMPTION REMOVED — see impute/[script].R (A##)`; assumption documented in impute/ |
| All clean/ scripts | `# 🚩 FLAG [EXCLUSION]: ...` comment blocks | Replaced with standardised `# EXCLUSION E##:` block; placeholder added to 05_exclusions_audit.R |
| All clean/ scripts | `# 🚩 FLAG [CROSS-SECTION]: ...` single-line comments | Replaced with full `# ⚠️ CROSS-SECTION DEPENDENCY` block |

------------------------------------------------------------------------

## Priority decisions before Stage 3

| Priority | Item | Who |
|----------------------------------|---------------------|------------------|
| 🔴 High | A17: Implement egg consumption allocation (consumptionNPS4.dta missing from pipeline) | Data/code |
| 🔴 High | A10: Confirm whether Alexander.2016 EW includes offal (double-count risk in MFA) | cannot be confirmed, sensitivity analysis |
| 🔴 High | E03: Confirm codebook meaning of ag3b_01b == 2 | Codebook |
| 🔴 High | E10: Confirm "crop produces no residue" is a genuine survey category (check double space) | Codebook |
| 🟡 Medium | A01/A06: Resolve NA conversion factors in recall.R and ag_produce.R | Literature |
| 🟡 Medium | A11: Confirm tethering definition in LSMS codebook | Codebook |
| 🟡 Medium | A22: Consolidate duplicate feed fraction tables into shared reference | Code |
| 🟢 Low | A02–A05: Crop area assumptions — well-supported by LSMS-ISA literature | Confirm only |
| 🟢 Low | A08, A13, A18, A24: Hardcoded household fixes — single-HH impact | Monitor |
