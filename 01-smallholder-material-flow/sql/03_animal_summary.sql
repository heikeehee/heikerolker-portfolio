-- =============================================================================
-- 03_animal_summary.sql
-- PURPOSE: Aggregate animal and animal product data to household level
-- R EQUIVALENT: scripts/clean/animals.R + animal_products.R + milk.R
-- Assumptions and flags: see R equivalent and backlog.md
-- =============================================================================

-- Animal counts by household
CREATE TABLE animal_summary AS
SELECT
    y4_hhid,
    SUM(CASE WHEN animal_type = 'Cattle' THEN n_animals ELSE 0 END) AS n_cattle,
    SUM(CASE WHEN animal_type = 'Goats'  THEN n_animals ELSE 0 END) AS n_goats,
    SUM(CASE WHEN animal_type = 'Sheep'  THEN n_animals ELSE 0 END) AS n_sheep,
    SUM(CASE WHEN animal_type IN ('Chickens','Ducks','Other poultry')
             THEN n_animals ELSE 0 END)                              AS n_poultry
FROM animals
GROUP BY y4_hhid;

-- Milk: convert litres to kg
-- R equivalent: mutate(milk_kg = milk_litres * 1.03) in scripts/clean/milk.R
-- Assumption: 1.03 kg per litre — see R equivalent for source and flag
CREATE TABLE milk_summary AS
SELECT
    y4_hhid,
    SUM(milk_litres * 1.03) AS total_milk_kg
FROM milk
GROUP BY y4_hhid;

-- Structural zero guard: households with no cattle → milk = 0 (not NULL)
-- R equivalent: case_when() pattern in 04_build_households.R
UPDATE milk_summary ms
SET total_milk_kg = 0
WHERE NOT EXISTS (
    SELECT 1 FROM animal_summary a
    WHERE a.y4_hhid = ms.y4_hhid AND a.n_cattle > 0
);
