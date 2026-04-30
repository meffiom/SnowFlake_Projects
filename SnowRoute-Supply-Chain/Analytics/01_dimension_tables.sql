-- ============================================================
-- FILE: 01_dimension_tables.sql
-- PROJECT: Supply Chain Intelligence Platform
-- PHASE: 5 — Analytics Layer (Gold)
-- DESCRIPTION: Creates all dimension tables for the star schema
-- RUN AS: DEVELOPER
-- ============================================================

-- ── Star schema design ───────────────────────────────────────
-- FACT table: fact_orders (one row per order line — 180k rows)
-- DIMENSION tables: describe WHO, WHAT, WHERE, WHEN
--   dim_date      → WHEN (calendar attributes)
--   dim_customers → WHO (customer attributes)
--   dim_products  → WHAT (product attributes)
--   dim_shipping  → HOW/WHERE (shipping route attributes)
--   dim_shipping_mode → simplified 4-row table for BI relationships

-- ── The SUM test (how to identify fact vs dimension columns) ──
-- SUM(sales) → makes sense → FACT column
-- SUM(customer_name) → nonsense → DIMENSION column
-- If summing it makes sense, it belongs in a fact table.


-- ── Step 1: Set context ──────────────────────────────────────
USE ROLE      DEVELOPER;
USE WAREHOUSE DEV_WH;
USE DATABASE  ANALYTICS_DB;
USE SCHEMA    ANALYTICS;


-- ════════════════════════════════════════════════════════════
-- dim_date: calendar dimension
-- Built from a date spine generator — no source data needed
-- Covers 10 years: 2015-01-01 to 2024-12-28 (3,650 rows)
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE TABLE ANALYTICS_DB.ANALYTICS.dim_date AS
WITH date_spine AS (
    SELECT
        DATEADD(DAY, SEQ4(), '2015-01-01'::DATE) AS full_date
    FROM TABLE(GENERATOR(ROWCOUNT => 3650))
)
SELECT
    TO_NUMBER(TO_CHAR(full_date, 'YYYYMMDD')) AS date_key,        -- Integer key: 20150101
    full_date,
    YEAR(full_date)                            AS year,
    QUARTER(full_date)                         AS quarter,
    MONTH(full_date)                           AS month,
    TO_CHAR(full_date, 'MMMM')                AS month_name,
    WEEKOFYEAR(full_date)                      AS week_of_year,
    DAYOFMONTH(full_date)                      AS day_of_month,
    DAYOFWEEK(full_date)                       AS day_of_week,
    TO_CHAR(full_date, 'DY')                   AS day_name,
    IFF(DAYOFWEEK(full_date) IN (0,6),
        TRUE, FALSE)                           AS is_weekend,
    CONCAT('Q', QUARTER(full_date),
           '-', YEAR(full_date))               AS quarter_label,   -- e.g. Q1-2015
    CONCAT(TO_CHAR(full_date, 'MON'),
           '-', YEAR(full_date))               AS month_year_label -- e.g. JAN-2015
FROM date_spine
ORDER BY full_date;

-- Verify
SELECT COUNT(*) AS total_dates FROM ANALYTICS_DB.ANALYTICS.dim_date;
SELECT * FROM ANALYTICS_DB.ANALYTICS.dim_date LIMIT 5;


-- ════════════════════════════════════════════════════════════
-- dim_customers: one row per unique customer
-- QUALIFY + ROW_NUMBER deduplicates — keeps most recent record per customer
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE TABLE ANALYTICS_DB.ANALYTICS.dim_customers AS
SELECT DISTINCT
    customer_id                                   AS customer_key,
    customer_id,
    customer_fname                                AS first_name,
    customer_lname                                AS last_name,
    CONCAT(customer_fname, ' ', customer_lname)   AS full_name,
    customer_segment                              AS segment,
    customer_city                                 AS city,
    customer_state                                AS state,
    customer_country                              AS country,
    customer_zipcode                              AS zipcode
FROM STAGING_DB.STAGING.stg_supply_chain
WHERE customer_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY customer_id
    ORDER BY order_date DESC   -- Keep most recent version of customer record
) = 1;

-- Verify
SELECT COUNT(*) AS total_customers FROM ANALYTICS_DB.ANALYTICS.dim_customers;
SELECT * FROM ANALYTICS_DB.ANALYTICS.dim_customers LIMIT 5;


-- ════════════════════════════════════════════════════════════
-- dim_products: one row per unique product
-- price_tier derived column groups products into Budget/Mid Range/Premium/Luxury
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE TABLE ANALYTICS_DB.ANALYTICS.dim_products AS
SELECT DISTINCT
    product_id                AS product_key,
    product_id,
    product_name,
    category_name             AS category,
    department_name           AS department,
    product_category_id,
    department_id,
    product_price,
    CASE
        WHEN product_price < 50  THEN 'Budget'
        WHEN product_price < 150 THEN 'Mid Range'
        WHEN product_price < 500 THEN 'Premium'
        ELSE 'Luxury'
    END                       AS price_tier
FROM STAGING_DB.STAGING.stg_supply_chain
WHERE product_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY product_id
    ORDER BY order_date DESC
) = 1;

-- Verify
SELECT COUNT(*) AS total_products FROM ANALYTICS_DB.ANALYTICS.dim_products;
SELECT * FROM ANALYTICS_DB.ANALYTICS.dim_products LIMIT 5;


-- ════════════════════════════════════════════════════════════
-- dim_shipping: shipping route dimension (mode + market + region)
-- Uses DISTINCT to ensure unique combinations — no duplicates
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE TABLE ANALYTICS_DB.ANALYTICS.dim_shipping AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY shipping_mode, market, order_region
    )                  AS shipping_key,
    shipping_mode,
    market,
    order_region,
    CASE
        WHEN shipping_mode = 'Same Day'     THEN 1
        WHEN shipping_mode = 'First Class'  THEN 2
        WHEN shipping_mode = 'Second Class' THEN 3
        ELSE 4
    END                AS shipping_speed_rank,
    CASE
        WHEN shipping_mode = 'Same Day'     THEN 'Express'
        WHEN shipping_mode = 'First Class'  THEN 'Fast'
        WHEN shipping_mode = 'Second Class' THEN 'Standard'
        ELSE 'Economy'
    END                AS shipping_tier
FROM (
    SELECT DISTINCT shipping_mode, market, order_region
    FROM STAGING_DB.STAGING.stg_supply_chain
    WHERE shipping_mode IS NOT NULL
      AND market        IS NOT NULL
      AND order_region  IS NOT NULL
);

-- Verify — should be ~92 rows, zero duplicates
SELECT COUNT(*) AS total_rows FROM ANALYTICS_DB.ANALYTICS.dim_shipping;

-- Confirm zero duplicates on join columns
SELECT shipping_mode, market, order_region, COUNT(*) AS cnt
FROM ANALYTICS_DB.ANALYTICS.dim_shipping
GROUP BY 1, 2, 3
HAVING COUNT(*) > 1;


-- ════════════════════════════════════════════════════════════
-- dim_shipping_mode: simplified 4-row table for BI tool joins
-- dim_shipping has 92 rows (one per route) which causes Many-to-Many
-- in Power BI. This table has exactly 4 rows — one per shipping mode.
-- Used as the bridge table in the Power BI data model.
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE TABLE ANALYTICS_DB.ANALYTICS.dim_shipping_mode AS
SELECT DISTINCT
    SHIPPING_MODE,
    CASE
        WHEN SHIPPING_MODE = 'Same Day'     THEN 'Express'
        WHEN SHIPPING_MODE = 'First Class'  THEN 'Fast'
        WHEN SHIPPING_MODE = 'Second Class' THEN 'Standard'
        ELSE 'Economy'
    END AS SHIPPING_TIER,
    CASE
        WHEN SHIPPING_MODE = 'Same Day'     THEN 1
        WHEN SHIPPING_MODE = 'First Class'  THEN 2
        WHEN SHIPPING_MODE = 'Second Class' THEN 3
        ELSE 4
    END AS SPEED_RANK
FROM ANALYTICS_DB.ANALYTICS.fact_orders
WHERE SHIPPING_MODE IS NOT NULL;

-- Verify — must be exactly 4 rows, zero duplicates
SELECT * FROM ANALYTICS_DB.ANALYTICS.dim_shipping_mode;

SELECT SHIPPING_MODE, COUNT(*) AS cnt
FROM ANALYTICS_DB.ANALYTICS.dim_shipping_mode
GROUP BY SHIPPING_MODE
HAVING COUNT(*) > 1;
-- Expected: 0 rows returned (no duplicates)
