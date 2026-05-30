-- =============================================================================
-- 03_animal_audit.sql
-- PURPOSE:
-- Audit livestock ownership and animal-product reporting across animals, milk,
-- and animal product modules.
--
-- BUSINESS QUESTION:
-- Where do livestock and animal-product modules show routing gaps, missingness,
-- or structural mismatches?
--
-- ENGINE:
-- DuckDB
--
-- INPUT:
-- data/processed/01/clean/*.rds or exported CSV equivalents
--
-- OUTPUT TABLES:
-- - animal_grain_summary
-- - animal_household_presence
-- - milk_household_presence
-- - animal_product_household_presence
-- - milkable_animal_support
-- - poultry_support
-- - egg_product_summary
-- - hides_product_summary
-- - milk_summary
-- - expected_but_missing_milk
-- - expected_but_missing_eggs
-- - expected_but_missing_hides
-- - animal_alignment_flags
-- - animal_review_targets
--
-- DESIGN NOTE:
-- Ownership universe      = animals_fin
-- Milk universe           = milk
-- Animal product universe = produce
--
-- Household-level routing checks come first.
-- Structural mismatches are flagged for review rather than silently repaired.
-- =============================================================================

CREATE OR REPLACE TABLE household_roster AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/household_roster.csv');

CREATE OR REPLACE TABLE animals_fin AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/animals_fin.csv');

CREATE OR REPLACE TABLE milk AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/milk.csv');

CREATE OR REPLACE TABLE produce AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/produce.csv');

CREATE OR REPLACE TABLE animal_grain_summary AS
SELECT
    'animals_fin' AS module_name,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT y4_hhid) AS n_households,
    COUNT(DISTINCT (CAST(y4_hhid AS VARCHAR) || '|' || CAST(lvstckid AS VARCHAR))) AS n_distinct_items,
    'y4_hhid + lvstckid' AS expected_grain
FROM animals_fin

UNION ALL

SELECT
    'milk' AS module_name,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT y4_hhid) AS n_households,
    COUNT(DISTINCT (CAST(y4_hhid AS VARCHAR) || '|' || CAST(lvstckcat AS VARCHAR))) AS n_distinct_items,
    'y4_hhid + lvstckcat' AS expected_grain
FROM milk

UNION ALL

SELECT
    'produce' AS module_name,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT y4_hhid) AS n_households,
    COUNT(DISTINCT (CAST(y4_hhid AS VARCHAR) || '|' || CAST(productid AS VARCHAR))) AS n_distinct_items,
    'y4_hhid + productid' AS expected_grain
FROM produce
ORDER BY module_name;

CREATE OR REPLACE TABLE animal_household_presence AS
WITH animals_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_animals
    FROM animals_fin
)
SELECT
    hr.y4_hhid,
    hr.region,
    hr.district,
    COALESCE(ah.in_animals, 0) AS in_animals
FROM household_roster hr
LEFT JOIN animals_hh ah
    ON hr.y4_hhid = ah.y4_hhid;

CREATE OR REPLACE TABLE milk_household_presence AS
WITH milk_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_milk
    FROM milk
)
SELECT
    hr.y4_hhid,
    hr.region,
    hr.district,
    COALESCE(mh.in_milk, 0) AS in_milk
FROM household_roster hr
LEFT JOIN milk_hh mh
    ON hr.y4_hhid = mh.y4_hhid;

CREATE OR REPLACE TABLE animal_product_household_presence AS
WITH prod_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_animal_products
    FROM produce
)
SELECT
    hr.y4_hhid,
    hr.region,
    hr.district,
    COALESCE(ph.in_animal_products, 0) AS in_animal_products
FROM household_roster hr
LEFT JOIN prod_hh ph
    ON hr.y4_hhid = ph.y4_hhid;

CREATE OR REPLACE TABLE milkable_animal_support AS
SELECT
    y4_hhid,
    SUM(COALESCE(max_owned, 0)) AS milkable_animals_supported,
    MAX(CASE WHEN COALESCE(flag_milk_animal, 0) = 1 THEN 1 ELSE 0 END) AS has_milkable_animal_row,
    COUNT(*) AS n_milkable_rows
FROM animals_fin
WHERE COALESCE(flag_milk_animal, 0) = 1
GROUP BY y4_hhid;

CREATE OR REPLACE TABLE poultry_support AS
SELECT
    y4_hhid,
    SUM(COALESCE(max_owned, 0)) AS poultry_supported,
    COUNT(*) AS n_poultry_rows
FROM animals_fin
WHERE type = 'poultry'
GROUP BY y4_hhid;

CREATE OR REPLACE TABLE milk_summary AS
SELECT
    y4_hhid,
    COUNT(*) AS n_milk_rows,
    SUM(COALESCE(milked, 0)) AS milked_animals_reported,
    SUM(COALESCE(length, 0)) AS total_milk_months_reported,
    SUM(COALESCE(av_raw, 0)) AS total_av_raw_litres_per_day,
    SUM(COALESCE(consumed_raw, 0)) AS total_consumed_raw_litres_per_day,
    SUM(COALESCE(sold_raw, 0)) AS total_sold_raw_litres_per_day,
    SUM(COALESCE(processed_raw, 0)) AS total_processed_raw_litres_per_day,
    SUM(COALESCE(psold_raw, 0)) AS total_psold_raw_litres_per_day,
    MAX(COALESCE(flag_milk_support_missing, 0)) AS flag_milk_support_missing,
    MAX(COALESCE(flag_section_mismatch_milked_gt_owned, 0)) AS flag_milked_gt_owned,
    MAX(COALESCE(flag_av_missing, 0)) AS flag_av_missing,
    MAX(COALESCE(flag_disposition_present_but_av_missing, 0)) AS flag_disp_present_but_av_missing,
    MAX(COALESCE(flag_disposition_exceeds_production, 0)) AS flag_disp_exceeds_production,
    MAX(COALESCE(flag_zero_milked_with_output, 0)) AS flag_zero_milked_with_output
FROM milk
GROUP BY y4_hhid;

CREATE OR REPLACE TABLE egg_product_summary AS
SELECT
    y4_hhid,
    COUNT(*) AS n_egg_rows,
    SUM(COALESCE(produced_raw, 0)) AS eggs_produced_raw,
    SUM(COALESCE(sold_raw, 0)) AS eggs_sold_raw,
    MAX(COALESCE(flag_eggs_section_misalignment, 0)) AS flag_eggs_section_misalignment,
    MAX(COALESCE(flag_eggs_feed_alignment_missing, 0)) AS flag_eggs_feed_alignment_missing,
    MAX(COALESCE(flag_chicken_no_egg, 0)) AS flag_chicken_no_egg,
    MAX(COALESCE(flag_egg_unaccounted, 0)) AS flag_egg_unaccounted,
    MAX(COALESCE(flag_egg_overuse, 0)) AS flag_egg_overuse
FROM produce
WHERE productid = 'eggs'
GROUP BY y4_hhid;

CREATE OR REPLACE TABLE hides_product_summary AS
SELECT
    y4_hhid,
    COUNT(*) AS n_hides_rows,
    SUM(COALESCE(produced_raw, 0)) AS hides_produced_raw,
    SUM(COALESCE(sold_raw, 0)) AS hides_sold_raw,
    MAX(COALESCE(flaghidessectionpresent, 0)) AS flag_hides_section_present,
    MAX(COALESCE(flaghidestruena, 0)) AS flag_hides_true_na
FROM produce
WHERE productid = 'skin / hides'
GROUP BY y4_hhid;

CREATE OR REPLACE TABLE expected_but_missing_milk AS
SELECT
    s.y4_hhid,
    s.milkable_animals_supported,
    s.has_milkable_animal_row,
    CASE
        WHEN s.has_milkable_animal_row = 1 AND m.y4_hhid IS NULL THEN 1
        ELSE 0
    END AS flag_milkable_animals_without_milk_module
FROM milkable_animal_support s
LEFT JOIN milk_summary m
    ON s.y4_hhid = m.y4_hhid
WHERE s.has_milkable_animal_row = 1
  AND m.y4_hhid IS NULL;

CREATE OR REPLACE TABLE expected_but_missing_eggs AS
SELECT
    p.y4_hhid,
    p.poultry_supported,
    CASE
        WHEN p.poultry_supported > 0 AND e.y4_hhid IS NULL THEN 1
        ELSE 0
    END AS flag_poultry_without_egg_module
FROM poultry_support p
LEFT JOIN egg_product_summary e
    ON p.y4_hhid = e.y4_hhid
WHERE p.poultry_supported > 0
  AND e.y4_hhid IS NULL;

CREATE OR REPLACE TABLE expected_but_missing_hides AS
SELECT
    a.y4_hhid,
    SUM(COALESCE(a.slaughter, 0)) AS slaughter_total,
    CASE
        WHEN SUM(COALESCE(a.slaughter, 0)) > 0 AND h.y4_hhid IS NULL THEN 1
        ELSE 0
    END AS flag_slaughter_without_hides_module
FROM animals_fin a
LEFT JOIN hides_product_summary h
    ON a.y4_hhid = h.y4_hhid
GROUP BY a.y4_hhid, h.y4_hhid
HAVING SUM(COALESCE(a.slaughter, 0)) > 0
   AND h.y4_hhid IS NULL;

CREATE OR REPLACE TABLE animal_alignment_flags AS
WITH livestock_support AS (
    SELECT
        y4_hhid,
        SUM(COALESCE(max_owned, 0)) AS total_supported_animals,
        SUM(COALESCE(slaughter, 0)) AS total_slaughter_reported,
        MAX(CASE WHEN COALESCE(max_owned, 0) > 0 THEN 1 ELSE 0 END) AS has_any_livestock
    FROM animals_fin
    GROUP BY y4_hhid
)
SELECT
    COALESCE(ls.y4_hhid, m.y4_hhid, e.y4_hhid, h.y4_hhid) AS y4_hhid,
    ls.total_supported_animals,
    ls.total_slaughter_reported,
    ls.has_any_livestock,
    ms.milkable_animals_supported,
    ms.has_milkable_animal_row,
    ps.poultry_supported,
    m.n_milk_rows,
    m.milked_animals_reported,
    m.total_av_raw_litres_per_day,
    m.total_consumed_raw_litres_per_day,
    m.total_sold_raw_litres_per_day,
    m.total_processed_raw_litres_per_day,
    m.flag_milk_support_missing,
    m.flag_milked_gt_owned,
    m.flag_av_missing,
    m.flag_disp_present_but_av_missing,
    m.flag_disp_exceeds_production,
    m.flag_zero_milked_with_output,
    e.n_egg_rows,
    e.eggs_produced_raw,
    e.eggs_sold_raw,
    e.flag_eggs_section_misalignment,
    e.flag_eggs_feed_alignment_missing,
    e.flag_chicken_no_egg,
    e.flag_egg_unaccounted,
    e.flag_egg_overuse,
    h.n_hides_rows,
    h.hides_produced_raw,
    h.hides_sold_raw,
    h.flag_hides_section_present,
    h.flag_hides_true_na,
    CASE
        WHEN COALESCE(ms.has_milkable_animal_row, 0) = 1 AND m.y4_hhid IS NULL THEN 1
        ELSE 0
    END AS flag_missing_milk_module,
    CASE
        WHEN COALESCE(ms.has_milkable_animal_row, 0) = 0 AND m.y4_hhid IS NOT NULL THEN 1
        ELSE 0
    END AS flag_milk_without_animal_support,
    CASE
        WHEN COALESCE(ps.poultry_supported, 0) > 0 AND e.y4_hhid IS NULL THEN 1
        ELSE 0
    END AS flag_missing_egg_module,
    CASE
        WHEN COALESCE(ps.poultry_supported, 0) = 0 AND e.y4_hhid IS NOT NULL THEN 1
        ELSE 0
    END AS flag_eggs_without_poultry_support,
    CASE
        WHEN COALESCE(ls.total_slaughter_reported, 0) > 0 AND h.y4_hhid IS NULL THEN 1
        ELSE 0
    END AS flag_missing_hides_module,
    CASE
        WHEN COALESCE(ls.has_any_livestock, 0) = 0
         AND (m.y4_hhid IS NOT NULL OR e.y4_hhid IS NOT NULL OR h.y4_hhid IS NOT NULL)
        THEN 1
        ELSE 0
    END AS flag_products_without_livestock
FROM livestock_support ls
FULL OUTER JOIN milk_summary m
    ON ls.y4_hhid = m.y4_hhid
LEFT JOIN milkable_animal_support ms
    ON COALESCE(ls.y4_hhid, m.y4_hhid) = ms.y4_hhid
LEFT JOIN poultry_support ps
    ON COALESCE(ls.y4_hhid, m.y4_hhid) = ps.y4_hhid
FULL OUTER JOIN egg_product_summary e
    ON COALESCE(ls.y4_hhid, m.y4_hhid) = e.y4_hhid
FULL OUTER JOIN hides_product_summary h
    ON COALESCE(ls.y4_hhid, m.y4_hhid, e.y4_hhid) = h.y4_hhid;

CREATE OR REPLACE TABLE animal_review_targets AS
SELECT
    y4_hhid,
    total_supported_animals,
    milkable_animals_supported,
    poultry_supported,
    total_slaughter_reported,
    n_milk_rows,
    n_egg_rows,
    n_hides_rows,
    flag_missing_milk_module,
    flag_milk_without_animal_support,
    flag_missing_egg_module,
    flag_eggs_without_poultry_support,
    flag_missing_hides_module,
    flag_products_without_livestock,
    flag_milk_support_missing,
    flag_milked_gt_owned,
    flag_av_missing,
    flag_disp_present_but_av_missing,
    flag_disp_exceeds_production,
    flag_zero_milked_with_output,
    flag_eggs_section_misalignment,
    flag_eggs_feed_alignment_missing,
    flag_chicken_no_egg,
    flag_egg_unaccounted,
    flag_egg_overuse,
    flag_hides_true_na,
    CASE
        WHEN flag_missing_milk_module = 1 THEN 'Milkable animals present but no milk module record'
        WHEN flag_milk_without_animal_support = 1 THEN 'Milk module record has no matching milkable-animal support'
        WHEN flag_missing_egg_module = 1 THEN 'Poultry present but no egg product record'
        WHEN flag_eggs_without_poultry_support = 1 THEN 'Egg record has no matching poultry support'
        WHEN flag_missing_hides_module = 1 THEN 'Slaughter reported but no hides record'
        WHEN flag_products_without_livestock = 1 THEN 'Animal product module present without livestock support'
        WHEN flag_milked_gt_owned = 1 THEN 'Milk section reports more milked animals than supported'
        WHEN flag_disp_exceeds_production = 1 THEN 'Milk disposition exceeds milk production'
        WHEN flag_zero_milked_with_output = 1 THEN 'Milk output present when milked count is zero'
        WHEN flag_eggs_section_misalignment = 1 THEN 'Egg record has no poultry support match'
        WHEN flag_egg_overuse = 1 THEN 'Eggs sold exceed eggs produced'
        WHEN flag_hides_true_na = 1 THEN 'Hides section present but both produced and sold are missing'
        ELSE 'Manual review'
    END AS review_reason
FROM animal_alignment_flags
WHERE flag_missing_milk_module = 1
   OR flag_milk_without_animal_support = 1
   OR flag_missing_egg_module = 1
   OR flag_eggs_without_poultry_support = 1
   OR flag_missing_hides_module = 1
   OR flag_products_without_livestock = 1
   OR flag_milk_support_missing = 1
   OR flag_milked_gt_owned = 1
   OR flag_av_missing = 1
   OR flag_disp_present_but_av_missing = 1
   OR flag_disp_exceeds_production = 1
   OR flag_zero_milked_with_output = 1
   OR flag_eggs_section_misalignment = 1
   OR flag_eggs_feed_alignment_missing = 1
   OR flag_chicken_no_egg = 1
   OR flag_egg_unaccounted = 1
   OR flag_egg_overuse = 1
   OR flag_hides_true_na = 1
ORDER BY y4_hhid;

SELECT * FROM animal_grain_summary ORDER BY module_name;

SELECT
    SUM(flag_missing_milk_module) AS n_missing_milk_module,
    SUM(flag_milk_without_animal_support) AS n_milk_without_animal_support,
    SUM(flag_missing_egg_module) AS n_missing_egg_module,
    SUM(flag_eggs_without_poultry_support) AS n_eggs_without_poultry_support,
    SUM(flag_missing_hides_module) AS n_missing_hides_module,
    SUM(flag_products_without_livestock) AS n_products_without_livestock
FROM animal_alignment_flags;