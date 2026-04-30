-- ============================================================
-- FILE: 03_kpi_views_and_materialized_view.sql
-- PROJECT: Supply Chain Intelligence Platform
-- PHASE: 5 — Analytics Layer (Gold)
-- DESCRIPTION: KPI views for SQL users + Materialized View for performance
-- RUN AS: DEVELOPER
-- ============================================================

-- ── Why views? ───────────────────────────────────────────────
-- Views serve SQL analysts who query Snowflake directly.
-- Instead of writing complex GROUP BY queries every time,
-- analysts can simply SELECT * FROM vw_daily_sales.
-- Views also serve BI tools connected via live connection.

-- ── Why a Materialized View? ─────────────────────────────────
-- A regular view re-runs the query every time it is queried.
-- A Materialized View pre-computes and stores the result.
-- Snowflake automatically refreshes it when the source changes.
-- Best for expensive aggregations hit frequently by dashboards.


-- ── Step 1: Set context ──────────────────────────────────────
USE ROLE      DEVELOPER;
USE WAREHOUSE DEV_WH;
USE DATABASE  ANALYTICS_DB;
USE SCHEMA    ANALYTICS;


-- ════════════════════════════════════════════════════════════
-- VIEW 1: vw_daily_sales
-- Grain: one row per day
-- Purpose: time series analysis — sales trends, late rate over time
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vw_daily_sales AS
SELECT
    f.order_date_only                        AS order_date,
    f.order_year                             AS year,
    f.order_month                            AS month,
    f.order_quarter                          AS quarter,
    d.month_name,
    d.month_year_label,
    d.quarter_label,
    COUNT(DISTINCT f.order_id)               AS total_orders,
    SUM(f.order_item_quantity)               AS total_units_sold,
    ROUND(SUM(f.sales), 2)                   AS total_sales,
    ROUND(SUM(f.profit), 2)                  AS total_profit,
    ROUND(AVG(f.profit_margin_pct), 2)       AS avg_profit_margin,
    SUM(IFF(f.is_late, 1, 0))               AS late_orders,
    COUNT(f.fact_key)                        AS total_order_lines,
    ROUND(SUM(IFF(f.is_late, 1, 0)) * 100.0
          / NULLIF(COUNT(f.fact_key), 0), 1) AS late_rate_pct
FROM fact_orders f
LEFT JOIN dim_date d ON f.date_key = d.date_key
GROUP BY 1, 2, 3, 4, 5, 6, 7;


-- ════════════════════════════════════════════════════════════
-- VIEW 2: vw_shipping_performance
-- Grain: one row per shipping mode + market + region combination
-- Purpose: late rate analysis by shipping route
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vw_shipping_performance AS
SELECT
    shipping_mode,
    market,
    order_region,
    COUNT(fact_key)                          AS total_shipments,
    SUM(IFF(is_late, 1, 0))                 AS late_shipments,
    ROUND(SUM(IFF(is_late, 1, 0)) * 100.0
          / NULLIF(COUNT(fact_key), 0), 1)   AS late_rate_pct,
    ROUND(AVG(delivery_delay_days), 2)       AS avg_delay_days,
    ROUND(SUM(sales), 2)                     AS total_sales,
    ROUND(AVG(profit_margin_pct), 2)         AS avg_profit_margin
FROM fact_orders
GROUP BY 1, 2, 3;


-- ════════════════════════════════════════════════════════════
-- VIEW 3: vw_product_performance
-- Grain: one row per product
-- Purpose: revenue and profitability analysis by product
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vw_product_performance AS
SELECT
    p.product_name,
    p.category,
    p.department,
    p.price_tier,
    COUNT(f.fact_key)                        AS total_orders,
    SUM(f.order_item_quantity)               AS total_units_sold,
    ROUND(SUM(f.sales), 2)                   AS total_sales,
    ROUND(SUM(f.profit), 2)                  AS total_profit,
    ROUND(AVG(f.profit_margin_pct), 2)       AS avg_profit_margin,
    ROUND(AVG(f.order_item_discount_rate)
          * 100, 2)                          AS avg_discount_pct
FROM fact_orders f
LEFT JOIN dim_products p ON f.product_key = p.product_key
GROUP BY 1, 2, 3, 4;


-- ════════════════════════════════════════════════════════════
-- VIEW 4: vw_customer_segments
-- Grain: one row per customer segment + country
-- Purpose: customer segmentation analysis
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vw_customer_segments AS
SELECT
    c.segment,
    c.country,
    COUNT(DISTINCT f.customer_key)           AS total_customers,
    COUNT(f.fact_key)                        AS total_orders,
    ROUND(SUM(f.sales), 2)                   AS total_sales,
    ROUND(AVG(f.sales), 2)                   AS avg_order_value,
    ROUND(SUM(f.profit), 2)                  AS total_profit,
    SUM(IFF(f.is_late, 1, 0))               AS late_deliveries,
    ROUND(SUM(IFF(f.is_late, 1, 0)) * 100.0
          / NULLIF(COUNT(f.fact_key), 0), 1) AS late_rate_pct
FROM fact_orders f
LEFT JOIN dim_customers c ON f.customer_key = c.customer_key
GROUP BY 1, 2;


-- ════════════════════════════════════════════════════════════
-- VIEW 5: vw_delay_summary
-- Grain: one row per delay severity + shipping mode + market
-- Purpose: delay breakdown analysis for dashboard
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vw_delay_summary AS
SELECT
    delay_severity,
    shipping_mode,
    market,
    COUNT(fact_key)                          AS total_orders,
    ROUND(COUNT(fact_key) * 100.0
          / SUM(COUNT(fact_key)) OVER(), 1)  AS pct_of_total,
    ROUND(AVG(delivery_delay_days), 2)       AS avg_delay_days,
    ROUND(SUM(sales), 2)                     AS total_sales_impacted
FROM fact_orders
GROUP BY 1, 2, 3;


-- ════════════════════════════════════════════════════════════
-- MATERIALIZED VIEW: mv_shipping_performance
-- Pre-computes the most expensive aggregation query
-- Snowflake auto-refreshes when fact_orders changes
-- Much faster than a regular view for dashboard queries
-- ════════════════════════════════════════════════════════════
CREATE OR REPLACE MATERIALIZED VIEW mv_shipping_performance AS
SELECT
    shipping_mode,
    market,
    order_region,
    COUNT(fact_key)                          AS total_shipments,
    SUM(IFF(is_late, 1, 0))                 AS late_shipments,
    ROUND(SUM(IFF(is_late, 1, 0)) * 100.0
          / NULLIF(COUNT(fact_key), 0), 1)   AS late_rate_pct,
    ROUND(AVG(delivery_delay_days), 2)       AS avg_delay_days,
    ROUND(SUM(sales), 2)                     AS total_sales
FROM fact_orders
GROUP BY 1, 2, 3;

-- Verify
SELECT * FROM mv_shipping_performance ORDER BY late_rate_pct DESC LIMIT 10;


-- ════════════════════════════════════════════════════════════
-- BUSINESS INSIGHT QUERIES
-- Run these to verify the views return meaningful results
-- These findings go directly into your README and dashboard
-- ════════════════════════════════════════════════════════════

-- Top 10 products by revenue
SELECT product_name, category, total_sales, total_profit, avg_profit_margin
FROM vw_product_performance
ORDER BY total_sales DESC
LIMIT 10;

-- Late rate by shipping mode
SELECT shipping_mode, total_shipments, late_shipments, late_rate_pct, avg_delay_days
FROM vw_shipping_performance
GROUP BY 1, 2, 3, 4, 5
ORDER BY late_rate_pct DESC;

-- Monthly sales trend
SELECT month_year_label, year, month, total_orders, total_sales, total_profit, late_rate_pct
FROM vw_daily_sales
GROUP BY 1, 2, 3, 4, 5, 6, 7
ORDER BY year, month;


-- ── Grant BI_READER access to all new objects ─────────────────
USE ROLE SYSADMIN;

GRANT SELECT ON ALL TABLES           IN SCHEMA ANALYTICS_DB.ANALYTICS TO ROLE BI_READER;
GRANT SELECT ON ALL VIEWS            IN SCHEMA ANALYTICS_DB.ANALYTICS TO ROLE BI_READER;
GRANT SELECT ON ALL MATERIALIZED VIEWS IN SCHEMA ANALYTICS_DB.ANALYTICS TO ROLE BI_READER;

-- Test BI_READER access
USE ROLE      BI_READER;
USE WAREHOUSE DEV_WH;

SELECT COUNT(*) FROM ANALYTICS_DB.ANALYTICS.fact_orders;
SELECT COUNT(*) FROM ANALYTICS_DB.ANALYTICS.vw_daily_sales;
