-- =============================================================================
-- 02_harvest_audit_diagnostics.sql
-- PURPOSE:
-- Diagnose duplication and overlap issues behind harvest audit mismatches.
--
-- NOTES:
-- This file is exploratory QC. It is not part of the portfolio-facing core
-- audit script.
-- =============================================================================

WITH prod_raw AS (
    SELECT y4_hhid, cropid
    FROM crops
    UNION ALL
    SELECT y4_hhid, cropid
    FROM trees
),
disp_raw AS (
    SELECT y4_hhid, cropid
    FROM crop_disp
    UNION ALL
    SELECT y4_hhid, cropid
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

WITH disp_raw AS (
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

WITH prod_raw AS (
    SELECT y4_hhid, cropid
    FROM crops
    UNION ALL
    SELECT y4_hhid, cropid
    FROM trees
),
disp_raw AS (
    SELECT y4_hhid, cropid
    FROM crop_disp
    UNION ALL
    SELECT y4_hhid, cropid
    FROM tree_disp
),
prod_key_counts AS (
    SELECT y4_hhid, cropid, COUNT(*) AS n_prod_rows
    FROM prod_raw
    GROUP BY y4_hhid, cropid
),
disp_key_counts AS (
    SELECT y4_hhid, cropid, COUNT(*) AS n_disp_rows
    FROM disp_raw
    GROUP BY y4_hhid, cropid
)
SELECT
    COALESCE(p.y4_hhid, d.y4_hhid) AS y4_hhid,
    COALESCE(p.cropid, d.cropid) AS cropid,
    p.n_prod_rows,
    d.n_disp_rows
FROM prod_key_counts p
FULL OUTER JOIN disp_key_counts d
    ON p.y4_hhid = d.y4_hhid
   AND p.cropid = d.cropid
WHERE COALESCE(p.n_prod_rows, 0) > 1
   OR COALESCE(d.n_disp_rows, 0) > 1
ORDER BY COALESCE(p.n_prod_rows, 0) DESC, COALESCE(d.n_disp_rows, 0) DESC;