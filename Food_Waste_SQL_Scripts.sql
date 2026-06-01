/*====================================================
Global Food Waste Analysis
Data Source: UNEP Food Waste Index
Tools: SQL Server, Power BI

Objective:
Clean, transform, validate and analyze global food
waste data to identify country, regional and sector
patterns.

Author: Eberechukwu Udeh
====================================================*/

----------------------------------------------
-- CREATE RAW TABLE
----------------------------------------------
CREATE TABLE food_waste (
    Country NVARCHAR(255),
    combined_figures NVARCHAR(50),
    household_kg NVARCHAR(50),
    household_tonnes NVARCHAR(50),
    retail_kg NVARCHAR(50),
    retail_tonnes NVARCHAR(50),
    food_service_kg NVARCHAR(50),
    food_service_tonnes NVARCHAR(50),
    confidence NVARCHAR(50),
    M49_code NVARCHAR(50),
    region NVARCHAR(100),
    source NVARCHAR(MAX)
);

-----------------------------------------------
-- IMPORT CSV DATA
------------------------------------------------
BULK INSERT food_waste
FROM 'C:\Temp\food_waste.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK,
    CODEPAGE = '65001'
);

-----------------------------------------------
-- CREATE CLEANED TABLE
--------------------------------------------------
SELECT
    TRIM(Country) AS country,

    TRY_CAST(combined_figures AS FLOAT) AS combined_kg_per_capita,
    TRY_CAST(household_kg AS FLOAT) AS household_kg_per_capita,
    TRY_CAST(household_tonnes AS FLOAT) AS household_tonnes,

    TRY_CAST(retail_kg AS FLOAT) AS retail_kg_per_capita,
    TRY_CAST(retail_tonnes AS FLOAT) AS retail_tonnes,

    TRY_CAST(food_service_kg AS FLOAT) AS food_service_kg_per_capita,
    TRY_CAST(food_service_tonnes AS FLOAT) AS food_service_tonnes,

    TRIM(confidence) AS confidence_level,
    TRY_CAST(M49_code AS INT) AS m49_code,
    TRIM(region) AS region

INTO food_waste_clean
FROM food_waste;

------------------------------------------------
-- REMOVE INVALID RECORDS
------------------------------------------------
DELETE FROM food_waste_clean
WHERE country LIKE '"%';

------------------------------------------------
-- STANDARDIZE TEXT VALUES
------------------------------------------------
UPDATE food_waste_clean
SET
    confidence_level = LOWER(TRIM(confidence_level)),
    region = TRIM(region),
    country = TRIM(country);

------------------------------------------------
-- FIX ENCODING ISSUES
------------------------------------------------
UPDATE food_waste_clean
SET country = 'Cote d''Ivoire'
WHERE country = 'CÃ´te dâ€™Ivoire';

UPDATE food_waste_clean
SET country = 'Curacao'
WHERE country = 'CuraÃ§ao';

------------------------------------------------
-- REMOVE NULL RECORDS
------------------------------------------------
DELETE FROM food_waste_clean
WHERE combined_kg_per_capita IS NULL;

------------------------------------------------
-- DATA VALIDATION CHECK
------------------------------------------------
SELECT COUNT(*) AS mismatched_rows
FROM food_waste_clean
WHERE combined_kg_per_capita <>
(
    household_kg_per_capita +
    retail_kg_per_capita +
    food_service_kg_per_capita
);

------------------------------------------------
-- CREATE FEATURE: HOUSEHOLD PERCENTAGE
------------------------------------------------
ALTER TABLE food_waste_clean
ADD household_percentage FLOAT;

UPDATE food_waste_clean
SET household_percentage =
(household_kg_per_capita / NULLIF(combined_kg_per_capita,0)) * 100;

------------------------------------------------
-- CREATE TRUSTED DATA VIEW
------------------------------------------------
CREATE VIEW vw_trusted_data AS
SELECT *
FROM food_waste_clean
WHERE confidence_level IN
('high confidence', 'medium confidence');

------------------------------------------------
-- TOP 10 COUNTRIES
------------------------------------------------
CREATE VIEW vw_top_countries AS
SELECT TOP 10
    country,
    combined_kg_per_capita
FROM vw_trusted_data
ORDER BY combined_kg_per_capita DESC;

------------------------------------------------
-- BOTTOM 10 COUNTRIES
------------------------------------------------
CREATE VIEW vw_bottom_countries AS
SELECT TOP 10
    country,
    combined_kg_per_capita
FROM vw_trusted_data
ORDER BY combined_kg_per_capita ASC;

------------------------------------------------
-- REGIONAL AVERAGE WASTE
------------------------------------------------
CREATE VIEW vw_region_analysis AS
SELECT
    region,
    AVG(combined_kg_per_capita) AS avg_waste_per_capita
FROM vw_trusted_data
GROUP BY region;

------------------------------------------------
-- TOTAL WASTE BY REGION
------------------------------------------------
CREATE VIEW vw_region_total_waste AS
SELECT
    region,
    SUM(household_tonnes + retail_tonnes + food_service_tonnes)
        AS total_waste_tonnes
FROM vw_trusted_data
GROUP BY region;

------------------------------------------------
-- GLOBAL SECTOR BREAKDOWN
------------------------------------------------
CREATE VIEW vw_global_sector_breakdown AS
SELECT
    SUM(household_kg_per_capita) AS household,
    SUM(retail_kg_per_capita) AS retail,
    SUM(food_service_kg_per_capita) AS food_service
FROM vw_trusted_data;

-----------------------------------------------
-- COUNTRY SECTOR BREAKDOWN
------------------------------------------------
CREATE VIEW vw_country_sector_breakdown AS
SELECT
    country,
    household_kg_per_capita,
    retail_kg_per_capita,
    food_service_kg_per_capita
FROM vw_trusted_data;

-----------------------------------------------
--HOUSEHOLD CONTRIBUTION
------------------------------------------------
CREATE VIEW vw_household_contribution AS
SELECT
    country,
    household_percentage
FROM vw_trusted_data;

------------------------------------------------
-- TOP HOUSEHOLD WASTE COUNTRIES
------------------------------------------------
CREATE VIEW vw_top_household_countries AS
SELECT TOP 10
    country,
    household_percentage
FROM vw_trusted_data
ORDER BY household_percentage DESC;

------------------------------------------------
-- REGION HOUSEHOLD AVERAGE
------------------------------------------------
CREATE VIEW vw_region_household_avg AS
SELECT
    region,
    AVG(household_percentage) AS avg_household_percentage
FROM vw_trusted_data
GROUP BY region;

-----------------------------------------------
-- COUNTRY RANKING
------------------------------------------------
CREATE VIEW vw_country_ranking AS
SELECT
    country,
    region,
    combined_kg_per_capita,
    RANK() OVER (
        ORDER BY combined_kg_per_capita DESC
    ) AS waste_rank
FROM vw_trusted_data;
