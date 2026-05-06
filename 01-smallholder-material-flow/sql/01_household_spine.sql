-- =============================================================================
-- 01_household_spine.sql
-- PURPOSE: Build household spine from union of all section tables
-- R EQUIVALENT: scripts/04_build_households.R — spine construction
-- Assumptions and flags: see R equivalent and backlog.md
-- =============================================================================

-- All households present in any section (union = full outer equivalent)
-- R equivalent: full_join / reduce across all section data frames

CREATE TABLE household_spine AS
SELECT DISTINCT y4_hhid FROM crops
UNION
SELECT DISTINCT y4_hhid FROM animals
UNION
SELECT DISTINCT y4_hhid FROM animal_products
UNION
SELECT DISTINCT y4_hhid FROM destinations
UNION
SELECT DISTINCT y4_hhid FROM recall;

-- Validate: count households
SELECT COUNT(*) AS n_households FROM household_spine;

-- Profile: households in spine but missing from crops section
-- R equivalent: anti_join(spine, crops, by = "y4_hhid")
SELECT s.y4_hhid
FROM household_spine s
LEFT JOIN crops c ON s.y4_hhid = c.y4_hhid
WHERE c.y4_hhid IS NULL;
