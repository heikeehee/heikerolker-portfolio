-- =============================================================================
-- 04_flow_allocation.sql
-- PURPOSE: Compute destination flow proportions per household
-- R EQUIVALENT: scripts/06_mfa_input.R — flow allocation
-- Assumptions and flags: see R equivalent and backlog.md
-- =============================================================================

-- Flow proportions: what share of harvest goes to each destination
-- R equivalent: mutate(prop_sold = sold_kg / harvest_kg) etc.
-- NOTE: The `destinations` table is expected to exist from raw data imports.
-- It is not created in these SQL scripts — load from R pipeline exports
-- (e.g. clean/destinations.R output, exported as CSV or parquet).

CREATE TABLE flow_allocation AS
SELECT
    y4_hhid,
    cropid,
    harvest_kg,
    sold_kg,
    consumed_kg,
    stored_kg,
    sent_to_processing_kg,
    ROUND(sold_kg              / NULLIF(harvest_kg, 0), 3) AS prop_sold,
    ROUND(consumed_kg          / NULLIF(harvest_kg, 0), 3) AS prop_consumed,
    ROUND(stored_kg            / NULLIF(harvest_kg, 0), 3) AS prop_stored,
    ROUND(sent_to_processing_kg/ NULLIF(harvest_kg, 0), 3) AS prop_processing,
    -- Mass balance gap
    harvest_kg - (
        COALESCE(sold_kg, 0) +
        COALESCE(consumed_kg, 0) +
        COALESCE(stored_kg, 0) +
        COALESCE(sent_to_processing_kg, 0) +
        COALESCE(gifted_kg, 0) +
        COALESCE(seed_kg, 0) +
        COALESCE(losses_kg, 0)
    ) AS balance_gap_kg
FROM crop_summary
JOIN destinations USING (y4_hhid, cropid);

-- Flag households with large balance gaps (>10% of harvest)
-- R equivalent: filter(abs(balance_pct) > 0.10) in 06_mfa_input.R
SELECT y4_hhid, cropid, harvest_kg, balance_gap_kg,
       ROUND(balance_gap_kg / NULLIF(harvest_kg,0), 3) AS balance_pct
FROM flow_allocation
WHERE ABS(balance_gap_kg / NULLIF(harvest_kg,0)) > 0.10
ORDER BY ABS(balance_gap_kg / NULLIF(harvest_kg,0)) DESC;
