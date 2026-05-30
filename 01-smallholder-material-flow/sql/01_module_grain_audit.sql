-- =============================================================================
-- 01_module_grain_audit.sql
-- PURPOSE:
-- Audit the structure and coverage of cleaned Project 01 module exports.
--
-- BUSINESS QUESTION:
-- Which outputs are household-level versus repeated-record tables, and which
-- households are missing from modules they were expected to enter?
--
-- ENGINE:
-- DuckDB
--
-- INPUT:
-- data/processed/01/sql_input/*.csv
--
-- OUTPUT TABLES:
-- - module_grain_summary
-- - household_module_presence
-- - expected_but_missing_households
--
-- GRAIN NOTE:
-- household_roster is the household spine (one row per y4_hhid).
-- Most other tables are lower-grain operational tables, for example:
-- y4_hhid + cropid, y4_hhid + lvstckid, or y4_hhid + productid.
--
-- INTERPRETATION NOTE:
-- A household appearing in a module means the household reached that module at
-- least once. It does not mean all downstream question fields were populated.
-- Question completeness and gate logic should be audited separately.
--
-- ACTION NOTE:
-- Review exceptions against survey routing, exclusion logic, and structural-zero
-- rules before treating them as data errors.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Load cleaned CSV exports
-- These are exported from the R clean stage and queried directly in DuckDB.
-- -----------------------------------------------------------------------------

DROP TABLE IF EXISTS household_roster;
CREATE OR REPLACE TABLE household_roster AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/household_roster.csv');

DROP TABLE IF EXISTS plots;
CREATE OR REPLACE TABLE plots AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/plots.csv');

DROP TABLE IF EXISTS plot_details;
CREATE OR REPLACE TABLE plot_details AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/plot_details.csv');

DROP TABLE IF EXISTS crops;
CREATE OR REPLACE TABLE crops AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/crops.csv');

DROP TABLE IF EXISTS crop_disp;
CREATE OR REPLACE TABLE crop_disp AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/crop_disp.csv');

DROP TABLE IF EXISTS trees;
CREATE OR REPLACE TABLE trees AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/trees.csv');

DROP TABLE IF EXISTS tree_disp;
CREATE OR REPLACE TABLE tree_disp AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/tree_disp.csv');

DROP TABLE IF EXISTS ag_produce;
CREATE OR REPLACE TABLE ag_produce AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/ag_produce.csv');

DROP TABLE IF EXISTS animals;
CREATE OR REPLACE TABLE animals AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/animals.csv');

DROP TABLE IF EXISTS animals_fin;
CREATE OR REPLACE TABLE animals_fin AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/animals_fin.csv');

DROP TABLE IF EXISTS crop_disp;
CREATE OR REPLACE TABLE produce AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/produce.csv');

DROP TABLE IF EXISTS hides;
CREATE OR REPLACE TABLE hides AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/hides.csv');

DROP TABLE IF EXISTS mass_eggs;
CREATE OR REPLACE TABLE mass_eggs AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/mass_eggs.csv');

DROP TABLE IF EXISTS milk;
CREATE OR REPLACE TABLE milk AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/milk.csv');


-- -----------------------------------------------------------------------------
-- Output 1: module_grain_summary
-- Purpose: show whether each module behaves like a household table or a repeated
-- operational table.
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS module_grain_summary;
CREATE OR REPLACE TABLE module_grain_summary AS
SELECT
    'household_roster' AS module_name,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT y4_hhid) AS n_households,
    'y4_hhid' AS expected_grain
FROM household_roster

UNION ALL

SELECT
    'plots' AS module_name,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT y4_hhid) AS n_households,
    'y4_hhid + plotnum' AS expected_grain
FROM plots

UNION ALL

SELECT
    'plot_details' AS module_name,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT y4_hhid) AS n_households,
    'y4_hhid + plotnum + season' AS expected_grain
FROM plot_details

UNION ALL

SELECT
    'crops' AS module_name,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT y4_hhid) AS n_households,
    'y4_hhid + cropid + plotnum' AS expected_grain
FROM crops

UNION ALL

SELECT
    'ag_produce' AS module_name,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT y4_hhid) AS n_households,
    'module-specific repeated rows' AS expected_grain
FROM ag_produce

UNION ALL

SELECT
    'animals' AS module_name,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT y4_hhid) AS n_households,
    'y4_hhid + lvstckid' AS expected_grain
FROM animals

UNION ALL

SELECT
    'animals_fin' AS module_name,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT y4_hhid) AS n_households,
    'y4_hhid + type' AS expected_grain
FROM animals_fin

UNION ALL

SELECT
    'produce' AS module_name,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT y4_hhid) AS n_households,
    'y4_hhid + productid' AS expected_grain
FROM produce

UNION ALL

SELECT
    'hides' AS module_name,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT y4_hhid) AS n_households,
    'subset of produce' AS expected_grain
FROM hides

UNION ALL

SELECT
    'mass_eggs' AS module_name,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT y4_hhid) AS n_households,
    'egg-specific product table' AS expected_grain
FROM mass_eggs

UNION ALL

SELECT
    'milk' AS module_name,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT y4_hhid) AS n_households,
    'y4_hhid + livestock item' AS expected_grain
FROM milk

ORDER BY module_name;


-- -----------------------------------------------------------------------------
-- Output 2: household_module_presence
-- Purpose: map whether each household appears in key downstream modules at least
-- once. This is a module-entry check, not a response-completeness check.
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS household_module_presence;
CREATE OR REPLACE TABLE household_module_presence AS
WITH plots_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_plots
    FROM plots
),
plot_details_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_plot_details
    FROM plot_details
),
crops_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_crops
    FROM crops
),
animals_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_animals
    FROM animals
),
animals_fin_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_animals_fin
    FROM animals_fin
),
produce_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_produce
    FROM produce
),
hides_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_hides
    FROM hides
),
mass_eggs_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_mass_eggs
    FROM mass_eggs
),
milk_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_milk
    FROM milk
)
SELECT
    hr.y4_hhid,
    hr.grew_crops,
    hr.did_process,
    hr.owned_animals,
    COALESCE(ph.in_plots, 0) AS in_plots,
    COALESCE(pdh.in_plot_details, 0) AS in_plot_details,
    COALESCE(ch.in_crops, 0) AS in_crops,
    COALESCE(ah.in_animals, 0) AS in_animals,
    COALESCE(afh.in_animals_fin, 0) AS in_animals_fin,
    COALESCE(prh.in_produce, 0) AS in_produce,
    COALESCE(hh.in_hides, 0) AS in_hides,
    COALESCE(meh.in_mass_eggs, 0) AS in_mass_eggs,
    COALESCE(mh.in_milk, 0) AS in_milk
FROM household_roster hr
LEFT JOIN plots_hh ph
    ON hr.y4_hhid = ph.y4_hhid
LEFT JOIN plot_details_hh pdh
    ON hr.y4_hhid = pdh.y4_hhid
LEFT JOIN crops_hh ch
    ON hr.y4_hhid = ch.y4_hhid
LEFT JOIN animals_hh ah
    ON hr.y4_hhid = ah.y4_hhid
LEFT JOIN animals_fin_hh afh
    ON hr.y4_hhid = afh.y4_hhid
LEFT JOIN produce_hh prh
    ON hr.y4_hhid = prh.y4_hhid
LEFT JOIN hides_hh hh
    ON hr.y4_hhid = hh.y4_hhid
LEFT JOIN mass_eggs_hh meh
    ON hr.y4_hhid = meh.y4_hhid
LEFT JOIN milk_hh mh
    ON hr.y4_hhid = mh.y4_hhid
;


-- Quick inspection outputs
SELECT *
FROM module_grain_summary
ORDER BY module_name;

SELECT *
FROM household_module_presence
LIMIT 20;


-- -----------------------------------------------------------------------------
-- Output 3: expected_but_missing_households
-- Purpose: flag households that should appear in key modules based on roster
-- participation flags but do not appear there.
--
-- Rule source:
-- household_roster participation flags are treated as the business expectation:
-- - grew_crops = should appear in crops
-- - did_process = should appear in ag_produce
-- - owned_animals = should appear in animals
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS expected_but_missing_households;
CREATE OR REPLACE TABLE expected_but_missing_households AS
WITH crops_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_crops
    FROM crops
),
ag_produce_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_ag_produce
    FROM ag_produce
),
animals_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_animals
    FROM animals
)
SELECT
    hr.y4_hhid,
    hr.region,
    hr.district,
    hr.grew_crops,
    hr.did_process,
    hr.owned_animals,
    COALESCE(ch.in_crops, 0) AS in_crops,
    COALESCE(aph.in_ag_produce, 0) AS in_ag_produce,
    COALESCE(ah.in_animals, 0) AS in_animals,
    CASE
        WHEN hr.grew_crops = TRUE
         AND COALESCE(ch.in_crops, 0) = 0
        THEN 1
        ELSE 0
    END AS flag_expected_crops_missing,
    CASE
        WHEN hr.did_process = TRUE
         AND COALESCE(aph.in_ag_produce, 0) = 0
        THEN 1
        ELSE 0
    END AS flag_expected_processing_missing,
    CASE
        WHEN hr.owned_animals = TRUE
         AND COALESCE(ah.in_animals, 0) = 0
        THEN 1
        ELSE 0
    END AS flag_expected_animals_missing
FROM household_roster hr
LEFT JOIN crops_hh ch
    ON hr.y4_hhid = ch.y4_hhid
LEFT JOIN ag_produce_hh aph
    ON hr.y4_hhid = aph.y4_hhid
LEFT JOIN animals_hh ah
    ON hr.y4_hhid = ah.y4_hhid
WHERE
    (hr.grew_crops = TRUE AND COALESCE(ch.in_crops, 0) = 0)
    OR (hr.did_process = TRUE AND COALESCE(aph.in_ag_produce, 0) = 0)
    OR (hr.owned_animals = TRUE AND COALESCE(ah.in_animals, 0) = 0)
ORDER BY hr.y4_hhid;


-- Summary counts for exception review
SELECT
    SUM(flag_expected_crops_missing) AS n_expected_crops_missing,
    SUM(flag_expected_processing_missing) AS n_expected_processing_missing,
    SUM(flag_expected_animals_missing) AS n_expected_animals_missing
FROM expected_but_missing_households;