-- ============================================================
-- FILE: 02_fact_table.sql
-- PROJECT: Supply Chain Intelligence Platform
-- PHASE: 5 — Analytics Layer (Gold)
-- DESCRIPTION: Creates the central fact table for the star schema
-- RUN AS: DEVELOPER (use PROD_WH — this is a large operation)
-- ============================================================

-- ── Design decisions ─────────────────────────────────────────
-- 1. ROW_NUMBER() generates a surrogate fact_key for each row
-- 2. Foreign keys (customer_key, product_key, date_key) link to dimensions
-- 3. All shipping/delivery columns kept directly in fact — avoids
--    the cartesian product explosion that occurs when joining dim_shipping
--    (dim_shipping has 92 rows per route — joining 180k × 92 = chaos)
-- 4. Test rows (order_id >= 999991) excluded via WHERE clause
-- 5. Built directly from STAGING — no joins to other tables


-- ── Step 1: Set context and use PROD_WH for speed ───────────
USE ROLE      DEVELOPER;
USE WAREHOUSE PROD_WH;    -- Required — this creates a 180k row table
USE DATABASE  ANALYTICS_DB;
USE SCHEMA    ANALYTICS;


-- ── Step 2: Create fact_orders ───────────────────────────────
CREATE OR REPLACE TABLE ANALYTICS_DB.ANALYTICS.fact_orders AS
SELECT
    -- Surrogate key (unique identifier for each fact row)
    ROW_NUMBER() OVER (
        ORDER BY order_id, order_item_id
    )                        AS fact_key,

    -- Foreign keys linking to dimension tables
    customer_id              AS customer_key,   -- → dim_customers
    product_id               AS product_key,    -- → dim_products
    TO_NUMBER(TO_CHAR(
        order_date_only, 'YYYYMMDD'
    ))                       AS date_key,       -- → dim_date (integer: 20150116)

    -- Order identifiers
    order_id,
    order_item_id,
    order_type,
    order_status,

    -- Date columns
    order_date,
    shipping_date,
    order_date_only,
    order_year,
    order_month,
    order_quarter,
    is_weekend,

    -- Shipping & delivery attributes
    shipping_mode,
    market,
    order_region,
    order_city,
    order_state,
    order_country,

    -- Delivery performance metrics (key measures for dashboard)
    days_shipping_real,
    days_shipping_scheduled,
    delivery_delay_days,        -- Positive = late, 0 or negative = on time
    is_late,                    -- TRUE/FALSE flag
    delay_severity,             -- On Time / Minor / Significant / Critical Delay
    delivery_status,
    late_delivery_risk,

    -- Financial measures (the numbers you aggregate in dashboards)
    sales,
    order_item_total,
    order_profit             AS profit,
    benefit_per_order,
    sales_per_customer,
    order_item_discount,
    order_item_discount_rate,
    order_item_product_price,
    order_item_profit_ratio,
    order_item_quantity,
    profit_margin_pct,

    -- Metadata
    ingestion_timestamp,
    source_file_name,
    batch_id

FROM STAGING_DB.STAGING.stg_supply_chain
WHERE order_id IS NOT NULL
  AND order_id < 999991;    -- Exclude test rows inserted during Stream testing


-- ── Step 3: Verify ──────────────────────────────────────────
-- Row count — should match staging minus 3 test rows
SELECT COUNT(*) AS total_fact_rows FROM ANALYTICS_DB.ANALYTICS.fact_orders;
-- Expected: ~180,519

-- Preview
SELECT * FROM ANALYTICS_DB.ANALYTICS.fact_orders LIMIT 5;

-- Sanity check on key business metrics
SELECT
    COUNT(DISTINCT order_id)                    AS unique_orders,
    COUNT(DISTINCT customer_key)                AS unique_customers,
    COUNT(DISTINCT product_key)                 AS unique_products,
    ROUND(SUM(sales), 2)                        AS total_revenue,
    ROUND(SUM(profit), 2)                       AS total_profit,
    ROUND(AVG(profit_margin_pct), 2)            AS avg_margin_pct,
    SUM(IFF(is_late, 1, 0))                    AS total_late_orders,
    ROUND(SUM(IFF(is_late,1,0)) * 100.0
          / COUNT(*), 1)                        AS late_rate_pct
FROM ANALYTICS_DB.ANALYTICS.fact_orders;
