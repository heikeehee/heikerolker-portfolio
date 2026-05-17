-- =============================================================================
-- 01_household_spine.sql
-- PURPOSE: Build household spine from union of all section tables
-- R EQUIVALENT: scripts/04_build_households.R — spine construction
-- Assumptions and flags: see R equivalent and backlog.md
-- =============================================================================

# ── Run the spine SQL ─────────────────────────────────────────────────────────
dbExecute(con, "
  CREATE OR REPLACE TABLE household_spine AS
  SELECT DISTINCT y4_hhid FROM pc
  UNION
  SELECT DISTINCT y4_hhid FROM animals_fin
  UNION
  SELECT DISTINCT y4_hhid FROM mass_eggs
  UNION
  SELECT DISTINCT y4_hhid FROM mass_milk_final
  UNION
  SELECT DISTINCT y4_hhid FROM recall
  UNION
  SELECT DISTINCT y4_hhid FROM crop_disp
  UNION
  SELECT DISTINCT y4_hhid FROM mass_agprod
")

# ── Validate ──────────────────────────────────────────────────────────────────
dbGetQuery(con, "SELECT COUNT(*) AS n_households FROM household_spine")

# ── Anti-join: households in spine but missing from pc (crops) ───────────────
missing_from_crops <- dbGetQuery(con, "
  SELECT s.y4_hhid
  FROM household_spine s
  LEFT JOIN pc c ON s.y4_hhid = c.y4_hhid
  WHERE c.y4_hhid IS NULL
")
message("Households in spine but not in crops: ", nrow(missing_from_crops))

# ── Clean up ──────────────────────────────────────────────────────────────────
duckdb::duckdb_unregister(con, "pc")
# ... repeat for each registered view
dbDisconnect(con, shutdown = TRUE)
