-- =============================================================================
-- 02_harvest_audit.sql
-- PURPOSE:
-- Audit the combined harvest production stream from crops and trees against the
-- combined disposition stream from crop_disp and tree_disp.
--
-- BUSINESS QUESTION:
-- Do harvested crop and tree items appear consistently across the production
-- universe, and do their disposition records align at the household-item level?
--
-- ENGINE:
-- DuckDB
--
-- INPUT:
-- data/processed/01/sql_input/*.csv
--
-- OUTPUT TABLES:
-- - production_grain_summary
-- - disposition_grain_summary
-- - production_household_presence
-- - disposition_household_presence
-- - expected_but_missing_disposition
-- - production_item_summary
-- - disposition_item_summary
-- - harvest_alignment_flags
--
-- DESIGN NOTE:
-- Production universe   = crops + trees
-- Disposition universe  = crop_disp + tree_disp
--
-- This script audits alignment at household-item grain first. It does not force
-- row-level equality across source modules with different natural grains.
-- =============================================================================

CREATE OR REPLACE TABLE household_roster AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/household_roster.csv');

CREATE OR REPLACE TABLE crops AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/crops.csv');

CREATE OR REPLACE TABLE trees AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/trees.csv');

CREATE OR REPLACE TABLE crop_disp AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/crop_disp.csv');

CREATE OR REPLACE TABLE tree_disp AS
SELECT *
FROM read_csv_auto('data/processed/01/sql_input/tree_disp.csv');

CREATE OR REPLACE TABLE production_grain_summary AS
SELECT
    'crops' AS module_name,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT y4_hhid) AS n_households,
    COUNT(DISTINCT (CAST(y4_hhid AS VARCHAR) || '|' || CAST(plotnum AS VARCHAR) || '|' || CAST(cropid AS VARCHAR))) AS n_distinct_items,
    'y4_hhid + plotnum + cropid' AS expected_grain
FROM crops

UNION ALL

SELECT
    'trees' AS module_name,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT y4_hhid) AS n_households,
    COUNT(DISTINCT (CAST(y4_hhid AS VARCHAR) || '|' || CAST(plotnum AS VARCHAR) || '|' || CAST(cropid AS VARCHAR))) AS n_distinct_items,
    'y4_hhid + plotnum + cropid' AS expected_grain
FROM trees
ORDER BY module_name;

CREATE OR REPLACE TABLE disposition_grain_summary AS
SELECT
    'crop_disp' AS module_name,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT y4_hhid) AS n_households,
    COUNT(DISTINCT (CAST(y4_hhid AS VARCHAR) || '|' || CAST(cropid AS VARCHAR))) AS n_distinct_items,
    'y4_hhid + cropid (+ season if retained)' AS expected_grain
FROM crop_disp

UNION ALL

SELECT
    'tree_disp' AS module_name,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT y4_hhid) AS n_households,
    COUNT(DISTINCT (CAST(y4_hhid AS VARCHAR) || '|' || CAST(cropid AS VARCHAR))) AS n_distinct_items,
    'y4_hhid + cropid (+ season if retained)' AS expected_grain
FROM tree_disp
ORDER BY module_name;

CREATE OR REPLACE TABLE production_household_presence AS
WITH crops_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_crops FROM crops
),
trees_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_trees FROM trees
),
production_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_production
    FROM (
        SELECT y4_hhid FROM crops
        UNION
        SELECT y4_hhid FROM trees
    ) x
)
SELECT
    hr.y4_hhid,
    hr.region,
    hr.district,
    hr.grew_crops,
    COALESCE(ch.in_crops, 0) AS in_crops,
    COALESCE(th.in_trees, 0) AS in_trees,
    COALESCE(ph.in_production, 0) AS in_production
FROM household_roster hr
LEFT JOIN crops_hh ch
    ON hr.y4_hhid = ch.y4_hhid
LEFT JOIN trees_hh th
    ON hr.y4_hhid = th.y4_hhid
LEFT JOIN production_hh ph
    ON hr.y4_hhid = ph.y4_hhid;

CREATE OR REPLACE TABLE disposition_household_presence AS
WITH crop_disp_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_crop_disp FROM crop_disp
),
tree_disp_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_tree_disp FROM tree_disp
),
disposition_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_disposition
    FROM (
        SELECT y4_hhid FROM crop_disp
        UNION
        SELECT y4_hhid FROM tree_disp
    ) x
)
SELECT
    hr.y4_hhid,
    hr.region,
    hr.district,
    hr.grew_crops,
    COALESCE(cdh.in_crop_disp, 0) AS in_crop_disp,
    COALESCE(tdh.in_tree_disp, 0) AS in_tree_disp,
    COALESCE(dh.in_disposition, 0) AS in_disposition
FROM household_roster hr
LEFT JOIN crop_disp_hh cdh
    ON hr.y4_hhid = cdh.y4_hhid
LEFT JOIN tree_disp_hh tdh
    ON hr.y4_hhid = tdh.y4_hhid
LEFT JOIN disposition_hh dh
    ON hr.y4_hhid = dh.y4_hhid;

CREATE OR REPLACE TABLE expected_but_missing_disposition AS
WITH production_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_production
    FROM (
        SELECT y4_hhid FROM crops
        UNION
        SELECT y4_hhid FROM trees
    ) x
),
disposition_hh AS (
    SELECT DISTINCT y4_hhid, 1 AS in_disposition
    FROM (
        SELECT y4_hhid FROM crop_disp
        UNION
        SELECT y4_hhid FROM tree_disp
    ) x
)
SELECT
    hr.y4_hhid,
    hr.region,
    hr.district,
    hr.grew_crops,
    COALESCE(ph.in_production, 0) AS in_production,
    COALESCE(dh.in_disposition, 0) AS in_disposition,
    CASE
        WHEN COALESCE(ph.in_production, 0) = 1
         AND COALESCE(dh.in_disposition, 0) = 0
        THEN 1
        ELSE 0
    END AS flag_production_without_disposition
FROM household_roster hr
LEFT JOIN production_hh ph
    ON hr.y4_hhid = ph.y4_hhid
LEFT JOIN disposition_hh dh
    ON hr.y4_hhid = dh.y4_hhid
WHERE COALESCE(ph.in_production, 0) = 1
  AND COALESCE(dh.in_disposition, 0) = 0
ORDER BY hr.y4_hhid;

CREATE OR REPLACE TABLE production_item_summary AS
WITH production_items AS (
    SELECT
        y4_hhid,
        cropid,
        'crops' AS source_module,
        COUNT(*) AS n_source_rows,
        SUM(CASE WHEN harvested = 'yes' THEN COALESCE(quant_harvest, 0) ELSE 0 END) AS qty_production_kg,
        SUM(CASE WHEN flag_harvest_quantity_missing = 1 THEN 1 ELSE 0 END) AS n_qty_missing_flags
    FROM crops
    GROUP BY y4_hhid, cropid

    UNION ALL

    SELECT
        y4_hhid,
        cropid,
        'trees' AS source_module,
        COUNT(*) AS n_source_rows,
        SUM(COALESCE(harvest, 0)) AS qty_production_kg,
        0 AS n_qty_missing_flags
    FROM trees
    GROUP BY y4_hhid, cropid
)
SELECT
    y4_hhid,
    cropid,
    SUM(n_source_rows) AS n_production_rows,
    SUM(qty_production_kg) AS production_kg,
    SUM(n_qty_missing_flags) AS n_production_qty_missing_flags,
    MAX(CASE WHEN source_module = 'crops' THEN 1 ELSE 0 END) AS from_crops,
    MAX(CASE WHEN source_module = 'trees' THEN 1 ELSE 0 END) AS from_trees
FROM production_items
GROUP BY y4_hhid, cropid;

CREATE OR REPLACE TABLE disposition_item_summary AS
WITH disposition_items AS (
    SELECT
        y4_hhid,
        cropid,
        'crop_disp' AS source_module,
        COUNT(*) AS n_source_rows,
        SUM(COALESCE(sold_raw, 0)) AS sold_kg,
        SUM(COALESCE(stored_raw, 0)) AS stored_kg,
        SUM(COALESCE(consumed_raw, 0)) AS consumed_kg,
        SUM(COALESCE(seed_raw, 0)) AS seed_kg,
        SUM(COALESCE(payment_raw, 0)) AS payment_kg,
        SUM(COALESCE(gifts_raw, 0)) AS gifts_kg,
        SUM(COALESCE(feed_raw, 0)) AS feed_kg,
        SUM(COALESCE(residue_raw, 0)) AS residue_kg,
        SUM(CASE WHEN sale = 'yes' AND sold_raw IS NULL THEN 1 ELSE 0 END) AS n_sale_missing_flags,
        SUM(CASE WHEN storage = 'yes' AND stored_raw IS NULL THEN 1 ELSE 0 END) AS n_storage_missing_flags,
        SUM(CASE WHEN lost = 'yes' AND losses_pct_raw IS NULL THEN 1 ELSE 0 END) AS n_loss_missing_flags
    FROM crop_disp
    GROUP BY y4_hhid, cropid

    UNION ALL

    SELECT
        y4_hhid,
        cropid,
        'tree_disp' AS source_module,
        COUNT(*) AS n_source_rows,
        SUM(COALESCE(sold_raw, 0)) AS sold_kg,
        SUM(COALESCE(stored_raw, 0)) AS stored_kg,
        SUM(COALESCE(consumed_raw, 0)) AS consumed_kg,
        SUM(COALESCE(seed_raw, 0)) AS seed_kg,
        SUM(COALESCE(payment_raw, 0)) AS payment_kg,
        SUM(COALESCE(gifts_raw, 0)) AS gifts_kg,
        SUM(COALESCE(feed_raw, 0)) AS feed_kg,
        0 AS residue_kg,
        SUM(CASE WHEN sale = 'yes' AND sold_raw IS NULL THEN 1 ELSE 0 END) AS n_sale_missing_flags,
        SUM(CASE WHEN storage = 'yes' AND stored_raw IS NULL THEN 1 ELSE 0 END) AS n_storage_missing_flags,
        SUM(CASE WHEN lost = 'yes' AND losses_pct_raw IS NULL THEN 1 ELSE 0 END) AS n_loss_missing_flags
    FROM tree_disp
    GROUP BY y4_hhid, cropid
)
SELECT
    y4_hhid,
    cropid,
    SUM(n_source_rows) AS n_disposition_rows,
    SUM(sold_kg) AS sold_kg,
    SUM(stored_kg) AS stored_kg,
    SUM(consumed_kg) AS consumed_kg,
    SUM(seed_kg) AS seed_kg,
    SUM(payment_kg) AS payment_kg,
    SUM(gifts_kg) AS gifts_kg,
    SUM(feed_kg) AS feed_kg,
    SUM(residue_kg) AS residue_kg,
    SUM(n_sale_missing_flags) AS n_sale_missing_flags,
    SUM(n_storage_missing_flags) AS n_storage_missing_flags,
    SUM(n_loss_missing_flags) AS n_loss_missing_flags,
    MAX(CASE WHEN source_module = 'crop_disp' THEN 1 ELSE 0 END) AS from_crop_disp,
    MAX(CASE WHEN source_module = 'tree_disp' THEN 1 ELSE 0 END) AS from_tree_disp
FROM disposition_items
GROUP BY y4_hhid, cropid;

CREATE OR REPLACE TABLE harvest_alignment_flags AS
SELECT
    COALESCE(p.y4_hhid, d.y4_hhid) AS y4_hhid,
    COALESCE(p.cropid, d.cropid) AS cropid,
    p.n_production_rows,
    p.production_kg,
    p.n_production_qty_missing_flags,
    p.from_crops,
    p.from_trees,
    d.n_disposition_rows,
    d.sold_kg,
    d.stored_kg,
    d.consumed_kg,
    d.seed_kg,
    d.payment_kg,
    d.gifts_kg,
    d.feed_kg,
    d.residue_kg,
    d.n_sale_missing_flags,
    d.n_storage_missing_flags,
    d.n_loss_missing_flags,
    d.from_crop_disp,
    d.from_tree_disp,
    CASE
        WHEN p.y4_hhid IS NOT NULL AND d.y4_hhid IS NULL THEN 1
        ELSE 0
    END AS flag_missing_disposition_item,
    CASE
        WHEN p.y4_hhid IS NULL AND d.y4_hhid IS NOT NULL THEN 1
        ELSE 0
    END AS flag_disposition_without_production,
    CASE
        WHEN COALESCE(d.sold_kg, 0)
           + COALESCE(d.stored_kg, 0)
           + COALESCE(d.consumed_kg, 0)
           + COALESCE(d.seed_kg, 0)
           + COALESCE(d.payment_kg, 0)
           + COALESCE(d.gifts_kg, 0)
           + COALESCE(d.feed_kg, 0)
           + COALESCE(d.residue_kg, 0)
           > COALESCE(p.production_kg, 0)
         AND p.y4_hhid IS NOT NULL
         AND d.y4_hhid IS NOT NULL
        THEN 1
        ELSE 0
    END AS flag_disposition_gt_production,
    CASE
        WHEN COALESCE(p.production_kg, 0) > 0
         AND COALESCE(d.sold_kg, 0)
           + COALESCE(d.stored_kg, 0)
           + COALESCE(d.consumed_kg, 0)
           + COALESCE(d.seed_kg, 0)
           + COALESCE(d.payment_kg, 0)
           + COALESCE(d.gifts_kg, 0)
           + COALESCE(d.feed_kg, 0)
           + COALESCE(d.residue_kg, 0) = 0
        THEN 1
        ELSE 0
    END AS flag_zero_recorded_disposition,
    (
        COALESCE(d.sold_kg, 0)
      + COALESCE(d.stored_kg, 0)
      + COALESCE(d.consumed_kg, 0)
      + COALESCE(d.seed_kg, 0)
      + COALESCE(d.payment_kg, 0)
      + COALESCE(d.gifts_kg, 0)
      + COALESCE(d.feed_kg, 0)
      + COALESCE(d.residue_kg, 0)
    ) AS total_disposition_kg,
    COALESCE(p.production_kg, 0)
      - (
        COALESCE(d.sold_kg, 0)
      + COALESCE(d.stored_kg, 0)
      + COALESCE(d.consumed_kg, 0)
      + COALESCE(d.seed_kg, 0)
      + COALESCE(d.payment_kg, 0)
      + COALESCE(d.gifts_kg, 0)
      + COALESCE(d.feed_kg, 0)
      + COALESCE(d.residue_kg, 0)
      ) AS residual_kg
FROM production_item_summary p
FULL OUTER JOIN disposition_item_summary d
    ON p.y4_hhid = d.y4_hhid
   AND p.cropid = d.cropid;

SELECT *
FROM production_grain_summary
ORDER BY module_name;

SELECT *
FROM disposition_grain_summary
ORDER BY module_name;

SELECT
    SUM(flag_production_without_disposition) AS n_households_production_without_disposition
FROM expected_but_missing_disposition;

SELECT
    SUM(flag_missing_disposition_item) AS n_missing_disposition_item,
    SUM(flag_disposition_without_production) AS n_disposition_without_production,
    SUM(flag_disposition_gt_production) AS n_disposition_gt_production,
    SUM(flag_zero_recorded_disposition) AS n_zero_recorded_disposition
FROM harvest_alignment_flags;

WITH prod_raw AS (
    SELECT y4_hhid, cropid, 'crops' AS source
    FROM crops
    UNION ALL
    SELECT y4_hhid, cropid, 'trees' AS source
    FROM trees
),
disp_raw AS (
    SELECT y4_hhid, cropid, 'crop_disp' AS source
    FROM crop_disp
    UNION ALL
    SELECT y4_hhid, cropid, 'tree_disp' AS source
    FROM tree_disp
)
SELECT
    side,
    COUNT(*) AS n_rows,
    COUNT(DISTINCT y4_hhid || '|' || cropid) AS n_distinct_keys,
    COUNT(*) - COUNT(DISTINCT y4_hhid || '|' || cropid) AS n_duplicate_rows
FROM (
    SELECT 'production' AS side, y4_hhid, cropid FROM prod_raw
    UNION ALL
    SELECT 'disposition' AS side, y4_hhid, cropid FROM disp_raw
) x
GROUP BY side;

WITH prod_raw AS (
    SELECT y4_hhid, cropid, 'crops' AS source
    FROM crops
    UNION ALL
    SELECT y4_hhid, cropid, 'trees' AS source
    FROM trees
),
disp_raw AS (
    SELECT y4_hhid, cropid, 'crop_disp' AS source
    FROM crop_disp
    UNION ALL
    SELECT y4_hhid, cropid, 'tree_disp' AS source
    FROM tree_disp
)
SELECT
    'production' AS side,
    y4_hhid,
    cropid,
    COUNT(*) AS n_rows
FROM prod_raw
GROUP BY y4_hhid, cropid
HAVING COUNT(*) > 1
ORDER BY n_rows DESC
LIMIT 25;

WITH prod_raw AS (
    SELECT y4_hhid, cropid, 'crops' AS source
    FROM crops
    UNION ALL
    SELECT y4_hhid, cropid, 'trees' AS source
    FROM trees
),
disp_raw AS (
    SELECT y4_hhid, cropid, 'crop_disp' AS source
    FROM crop_disp
    UNION ALL
    SELECT y4_hhid, cropid, 'tree_disp' AS source
    FROM tree_disp
)
SELECT
    'disposition' AS side,
    y4_hhid,
    cropid,
    COUNT(*) AS n_rows
FROM disp_raw
GROUP BY y4_hhid, cropid
HAVING COUNT(*) > 1
ORDER BY n_rows DESC
LIMIT 25;