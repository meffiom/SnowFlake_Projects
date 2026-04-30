-- ============================================================
-- FILE: 01_staging_layer.sql
-- PROJECT: Supply Chain Intelligence Platform
-- PHASE: 3 — Staging Layer (Silver)
-- DESCRIPTION: Cleans, types, and enriches raw data
-- RUN AS: DEVELOPER
-- ============================================================

-- ── What happens in the staging layer? ──────────────────────
-- 1. Cast VARCHAR columns to proper types (numbers, timestamps, booleans)
-- 2. Rename messy column names to clean snake_case
-- 3. Derive new business columns:
--    - delivery_delay_days: actual days minus scheduled days
--    - is_late: TRUE/FALSE flag
--    - delay_severity: On Time / Minor / Significant / Critical
--    - profit_margin_pct: profit as % of sales
-- 4. Parse dates from M/DD/YYYY H:MM format using TRY_TO_TIMESTAMP
--    (TRY_ prefix means failed casts return NULL instead of erroring)
-- 5. Extract date parts: year, month, quarter, day_of_week, is_weekend


-- ── Step 1: Set context ──────────────────────────────────────
USE ROLE      DEVELOPER;
USE WAREHOUSE DEV_WH;
USE DATABASE  STAGING_DB;
USE SCHEMA    STAGING;


-- ── Step 2: Preview raw data before transforming ─────────────
-- Always inspect the source before writing transformation logic
SELECT
    order_id,
    order_date,         -- Format: M/DD/YYYY H:MM e.g. 1/16/2015 8:33
    shipping_date,
    days_for_shipping_real,
    days_for_shipment_scheduled,
    delivery_status,
    sales,
    order_profit_per_order,
    market,
    shipping_mode
FROM RAW_DB.RAW.supply_chain_raw
LIMIT 5;


-- ── Step 3: Create staging table with full transformations ────
CREATE OR REPLACE TABLE STAGING_DB.STAGING.stg_supply_chain AS
SELECT
    -- ── Order identifiers ────────────────────────────────────
    TRY_CAST(order_id          AS NUMBER(10,0)) AS order_id,
    TRY_CAST(order_customer_id AS NUMBER(10,0)) AS order_customer_id,
    TRY_CAST(order_item_id     AS NUMBER(10,0)) AS order_item_id,

    -- ── Date columns — parsed from M/DD/YYYY H:MM format ────
    TRY_TO_TIMESTAMP(order_date,    'MM/DD/YYYY HH24:MI') AS order_date,
    TRY_TO_TIMESTAMP(shipping_date, 'MM/DD/YYYY HH24:MI') AS shipping_date,

    -- ── Derived date parts ───────────────────────────────────
    TRY_TO_DATE(order_date, 'MM/DD/YYYY HH24:MI')                         AS order_date_only,
    YEAR(TRY_TO_TIMESTAMP(order_date,    'MM/DD/YYYY HH24:MI'))            AS order_year,
    MONTH(TRY_TO_TIMESTAMP(order_date,   'MM/DD/YYYY HH24:MI'))            AS order_month,
    QUARTER(TRY_TO_TIMESTAMP(order_date, 'MM/DD/YYYY HH24:MI'))            AS order_quarter,
    DAYOFWEEK(TRY_TO_TIMESTAMP(order_date, 'MM/DD/YYYY HH24:MI'))          AS order_day_of_week,
    IFF(DAYOFWEEK(TRY_TO_TIMESTAMP(order_date, 'MM/DD/YYYY HH24:MI'))
        IN (0,6), TRUE, FALSE)                                             AS is_weekend,

    -- ── Shipping & delay columns ─────────────────────────────
    TRY_CAST(days_for_shipping_real      AS NUMBER(5,0)) AS days_shipping_real,
    TRY_CAST(days_for_shipment_scheduled AS NUMBER(5,0)) AS days_shipping_scheduled,

    -- KEY DERIVED COLUMN: how many days late was this shipment?
    -- Positive = late, Zero or negative = on time or early
    TRY_CAST(days_for_shipping_real      AS NUMBER(5,0))
        - TRY_CAST(days_for_shipment_scheduled AS NUMBER(5,0)) AS delivery_delay_days,

    -- KEY DERIVED COLUMN: simple TRUE/FALSE late flag
    IFF(TRY_CAST(days_for_shipping_real AS NUMBER(5,0))
        > TRY_CAST(days_for_shipment_scheduled AS NUMBER(5,0)),
        TRUE, FALSE)                                           AS is_late,

    -- KEY DERIVED COLUMN: categorise delay into severity buckets
    CASE
        WHEN TRY_CAST(days_for_shipping_real AS NUMBER(5,0))
             <= TRY_CAST(days_for_shipment_scheduled AS NUMBER(5,0))
             THEN 'On Time'
        WHEN TRY_CAST(days_for_shipping_real AS NUMBER(5,0))
             - TRY_CAST(days_for_shipment_scheduled AS NUMBER(5,0))
             BETWEEN 1 AND 3
             THEN 'Minor Delay'
        WHEN TRY_CAST(days_for_shipping_real AS NUMBER(5,0))
             - TRY_CAST(days_for_shipment_scheduled AS NUMBER(5,0))
             BETWEEN 4 AND 7
             THEN 'Significant Delay'
        ELSE 'Critical Delay'
    END                                                        AS delay_severity,

    -- ── Delivery & order type ────────────────────────────────
    delivery_status,
    TRY_CAST(late_delivery_risk AS NUMBER(1,0)) AS late_delivery_risk,
    shipping_mode,
    type                                        AS order_type,
    order_status,

    -- ── Financial columns ────────────────────────────────────
    TRY_CAST(sales                    AS NUMBER(12,4)) AS sales,
    TRY_CAST(order_item_total         AS NUMBER(12,4)) AS order_item_total,
    TRY_CAST(order_profit_per_order   AS NUMBER(12,4)) AS order_profit,
    TRY_CAST(benefit_per_order        AS NUMBER(12,4)) AS benefit_per_order,
    TRY_CAST(sales_per_customer       AS NUMBER(12,4)) AS sales_per_customer,
    TRY_CAST(order_item_discount      AS NUMBER(12,4)) AS order_item_discount,
    TRY_CAST(order_item_discount_rate AS NUMBER(6,4))  AS order_item_discount_rate,
    TRY_CAST(order_item_product_price AS NUMBER(12,4)) AS order_item_product_price,
    TRY_CAST(order_item_profit_ratio  AS NUMBER(6,4))  AS order_item_profit_ratio,
    TRY_CAST(order_item_quantity      AS NUMBER(10,0)) AS order_item_quantity,

    -- KEY DERIVED COLUMN: profit margin as a percentage of sales
    -- NULLIF prevents division by zero errors
    ROUND(
        TRY_CAST(order_profit_per_order AS NUMBER(12,4))
        / NULLIF(TRY_CAST(sales AS NUMBER(12,4)), 0) * 100
    , 2)                                               AS profit_margin_pct,

    -- ── Customer columns ─────────────────────────────────────
    TRY_CAST(customer_id AS NUMBER(10,0)) AS customer_id,
    customer_fname,
    customer_lname,
    customer_segment,
    customer_city,
    customer_state,
    customer_country,
    customer_zipcode,
    customer_street,

    -- ── Product columns ──────────────────────────────────────
    TRY_CAST(product_card_id     AS NUMBER(10,0)) AS product_id,
    TRY_CAST(product_category_id AS NUMBER(10,0)) AS product_category_id,
    product_name,
    category_name,
    department_name,
    TRY_CAST(department_id  AS NUMBER(10,0)) AS department_id,
    TRY_CAST(product_price  AS NUMBER(12,4)) AS product_price,
    TRY_CAST(product_status AS NUMBER(1,0))  AS product_status,

    -- ── Geography columns ────────────────────────────────────
    market,
    order_region,
    order_city,
    order_state,
    order_country,
    order_zipcode,
    TRY_CAST(latitude  AS NUMBER(10,6)) AS latitude,
    TRY_CAST(longitude AS NUMBER(10,6)) AS longitude,

    -- ── Metadata columns (carried forward from RAW) ──────────
    ingestion_timestamp,
    source_file_name,
    batch_id

FROM RAW_DB.RAW.supply_chain_raw;


-- ── Step 4: Validate staging data quality ────────────────────
-- Row count must match RAW exactly — no rows should be lost
SELECT COUNT(*) AS total_rows FROM STAGING_DB.STAGING.stg_supply_chain;
-- Expected: 180,519

-- Check key columns for NULLs and derived column correctness
SELECT
    COUNT(*)                                    AS total_rows,
    COUNT(order_id)                             AS valid_order_ids,
    COUNT(order_date)                           AS valid_order_dates,
    COUNT(sales)                                AS valid_sales,
    COUNT(order_profit)                         AS valid_profits,
    SUM(IFF(is_late = TRUE,  1, 0))            AS late_orders,
    SUM(IFF(is_late = FALSE, 1, 0))            AS on_time_orders,
    ROUND(AVG(delivery_delay_days), 2)          AS avg_delay_days
FROM STAGING_DB.STAGING.stg_supply_chain;


-- ── Step 5: Business insight — delay severity distribution ────
-- First real business finding from the data
SELECT
    delay_severity,
    COUNT(*)                                              AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1)   AS pct
FROM STAGING_DB.STAGING.stg_supply_chain
GROUP BY delay_severity
ORDER BY order_count DESC;
-- Key finding: only 42.7% of orders arrive on time
