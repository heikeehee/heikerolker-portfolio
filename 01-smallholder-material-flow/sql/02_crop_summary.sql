-- =============================================================================
-- 02_crop_summary.sql
-- PURPOSE: Aggregate crop data to household level
-- R EQUIVALENT: scripts/clean/crops.R + 04_build_households.R
-- Assumptions and flags: see R equivalent and backlog.md
-- =============================================================================

-- Household-level crop summary
-- R equivalent: group_by(y4_hhid) |> summarise()
-- NOTE: SUM ignores NULLs in SQL (equivalent to na.rm = TRUE in R)
-- Flag: NULLs here may be structural zeros or missing data — see R flags

CREATE TABLE crop_summary AS
SELECT
    y4_hhid,
    COUNT(DISTINCT cropid)       AS n_crops,
    COUNT(DISTINCT plot_id)      AS n_plots,
    SUM(harvest_kg)              AS total_harvest_kg,
    SUM(sold_kg)                 AS total_sold_kg,
    SUM(consumed_kg)             AS total_consumed_kg,
    SUM(stored_kg)               AS total_stored_kg,
    SUM(sent_to_processing_kg)   AS total_processing_kg
FROM crops
GROUP BY y4_hhid;

-- Crops with no matching destination record
-- R equivalent: anti_join(crops, destinations, by = c("y4_hhid", "cropid"))
-- FINDING: misalignment between production and destination sections
SELECT c.y4_hhid, c.cropid
FROM crops c
LEFT JOIN destinations d
  ON c.y4_hhid = d.y4_hhid AND c.cropid = d.cropid
WHERE d.cropid IS NULL;
