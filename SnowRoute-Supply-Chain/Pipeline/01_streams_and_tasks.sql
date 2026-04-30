-- ============================================================
-- FILE: 01_streams_and_tasks.sql
-- PROJECT: Supply Chain Intelligence Platform
-- PHASE: 4 — Automated Pipeline (Streams & Tasks)
-- DESCRIPTION: CDC stream on RAW table + Task to refresh STAGING
-- RUN AS: SYSADMIN (for Task creation), DEVELOPER (for testing)
-- ============================================================

-- ── What are Streams? ────────────────────────────────────────
-- A Stream is Snowflake's built-in Change Data Capture (CDC) mechanism.
-- It automatically tracks every INSERT, UPDATE, and DELETE on a table
-- with metadata columns: METADATA$ACTION, METADATA$ISUPDATE, METADATA$ROW_ID
-- No external tools needed — CDC is native to Snowflake.

-- ── What are Tasks? ──────────────────────────────────────────
-- Tasks are Snowflake's native orchestrator — like Airflow DAGs but built-in.
-- They run SQL or stored procedures on a schedule or when triggered.
-- Here we use WHEN SYSTEM$STREAM_HAS_DATA() to fire only when new data exists.
-- This replaces external orchestrators like Airflow for Snowflake-native pipelines.


-- ════════════════════════════════════════════════════════════
-- PART 1: STREAM SETUP
-- ════════════════════════════════════════════════════════════

USE ROLE      DEVELOPER;
USE WAREHOUSE DEV_WH;
USE DATABASE  RAW_DB;
USE SCHEMA    RAW;

-- ── Create Stream on RAW table ───────────────────────────────
-- APPEND_ONLY = TRUE: only captures INSERTs (not updates/deletes)
-- This is correct for our use case — we only ever add new orders
CREATE OR REPLACE STREAM raw_supply_chain_stream
    ON TABLE  RAW_DB.RAW.supply_chain_raw
    APPEND_ONLY = TRUE
    COMMENT     = 'Captures new rows inserted into supply_chain_raw';

-- Verify stream was created
SHOW STREAMS IN SCHEMA RAW_DB.RAW;

-- Check if stream has data (should be FALSE right after creation)
SELECT SYSTEM$STREAM_HAS_DATA('RAW_DB.RAW.raw_supply_chain_stream')
AS has_new_data;


-- ════════════════════════════════════════════════════════════
-- PART 2: TASK SETUP
-- ════════════════════════════════════════════════════════════

-- ── Grant permissions needed for Task execution ──────────────
USE ROLE ACCOUNTADMIN;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE DEVELOPER;

USE ROLE SYSADMIN;
GRANT ALL ON TASK RAW_DB.RAW.refresh_staging_task TO ROLE DEVELOPER;

-- ── Create Task (as SYSADMIN to avoid permission issues) ─────
-- Schedule: every 60 minutes
-- Condition: only runs when Stream has new data — saves credits
USE ROLE      SYSADMIN;
USE WAREHOUSE DEV_WH;

CREATE OR REPLACE TASK RAW_DB.RAW.refresh_staging_task
    WAREHOUSE = DEV_WH
    SCHEDULE  = '60 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('RAW_DB.RAW.raw_supply_chain_stream')
AS
INSERT INTO STAGING_DB.STAGING.stg_supply_chain
SELECT
    TRY_CAST(order_id            AS NUMBER(10,0)),
    TRY_CAST(order_customer_id   AS NUMBER(10,0)),
    TRY_CAST(order_item_id       AS NUMBER(10,0)),
    TRY_TO_TIMESTAMP(order_date,    'MM/DD/YYYY HH24:MI'),
    TRY_TO_TIMESTAMP(shipping_date, 'MM/DD/YYYY HH24:MI'),
    TRY_TO_DATE(order_date, 'MM/DD/YYYY HH24:MI'),
    YEAR(TRY_TO_TIMESTAMP(order_date,    'MM/DD/YYYY HH24:MI')),
    MONTH(TRY_TO_TIMESTAMP(order_date,   'MM/DD/YYYY HH24:MI')),
    QUARTER(TRY_TO_TIMESTAMP(order_date, 'MM/DD/YYYY HH24:MI')),
    DAYOFWEEK(TRY_TO_TIMESTAMP(order_date, 'MM/DD/YYYY HH24:MI')),
    IFF(DAYOFWEEK(TRY_TO_TIMESTAMP(order_date, 'MM/DD/YYYY HH24:MI')) IN (0,6), TRUE, FALSE),
    TRY_CAST(days_for_shipping_real      AS NUMBER(5,0)),
    TRY_CAST(days_for_shipment_scheduled AS NUMBER(5,0)),
    TRY_CAST(days_for_shipping_real AS NUMBER(5,0)) - TRY_CAST(days_for_shipment_scheduled AS NUMBER(5,0)),
    IFF(TRY_CAST(days_for_shipping_real AS NUMBER(5,0)) > TRY_CAST(days_for_shipment_scheduled AS NUMBER(5,0)), TRUE, FALSE),
    CASE
        WHEN TRY_CAST(days_for_shipping_real AS NUMBER(5,0)) <= TRY_CAST(days_for_shipment_scheduled AS NUMBER(5,0)) THEN 'On Time'
        WHEN TRY_CAST(days_for_shipping_real AS NUMBER(5,0)) - TRY_CAST(days_for_shipment_scheduled AS NUMBER(5,0)) BETWEEN 1 AND 3 THEN 'Minor Delay'
        WHEN TRY_CAST(days_for_shipping_real AS NUMBER(5,0)) - TRY_CAST(days_for_shipment_scheduled AS NUMBER(5,0)) BETWEEN 4 AND 7 THEN 'Significant Delay'
        ELSE 'Critical Delay'
    END,
    delivery_status,
    TRY_CAST(late_delivery_risk AS NUMBER(1,0)),
    shipping_mode,
    type,
    order_status,
    TRY_CAST(sales                    AS NUMBER(12,4)),
    TRY_CAST(order_item_total         AS NUMBER(12,4)),
    TRY_CAST(order_profit_per_order   AS NUMBER(12,4)),
    TRY_CAST(benefit_per_order        AS NUMBER(12,4)),
    TRY_CAST(sales_per_customer       AS NUMBER(12,4)),
    TRY_CAST(order_item_discount      AS NUMBER(12,4)),
    TRY_CAST(order_item_discount_rate AS NUMBER(6,4)),
    TRY_CAST(order_item_product_price AS NUMBER(12,4)),
    TRY_CAST(order_item_profit_ratio  AS NUMBER(6,4)),
    TRY_CAST(order_item_quantity      AS NUMBER(10,0)),
    ROUND(TRY_CAST(order_profit_per_order AS NUMBER(12,4)) / NULLIF(TRY_CAST(sales AS NUMBER(12,4)), 0) * 100, 2),
    TRY_CAST(customer_id AS NUMBER(10,0)),
    customer_fname,
    customer_lname,
    customer_segment,
    customer_city,
    customer_state,
    customer_country,
    customer_zipcode,
    customer_street,
    TRY_CAST(product_card_id     AS NUMBER(10,0)),
    TRY_CAST(product_category_id AS NUMBER(10,0)),
    product_name,
    category_name,
    department_name,
    TRY_CAST(department_id  AS NUMBER(10,0)),
    TRY_CAST(product_price  AS NUMBER(12,4)),
    TRY_CAST(product_status AS NUMBER(1,0)),
    market,
    order_region,
    order_city,
    order_state,
    order_country,
    order_zipcode,
    TRY_CAST(latitude  AS NUMBER(10,6)),
    TRY_CAST(longitude AS NUMBER(10,6)),
    ingestion_timestamp,
    source_file_name,
    batch_id
FROM RAW_DB.RAW.raw_supply_chain_stream;

-- Resume task (tasks start in SUSPENDED state by default)
ALTER TASK RAW_DB.RAW.refresh_staging_task RESUME;

-- Verify task is active
SHOW TASKS IN SCHEMA RAW_DB.RAW;


-- ════════════════════════════════════════════════════════════
-- PART 3: TEST THE PIPELINE END TO END
-- ════════════════════════════════════════════════════════════

-- ── Insert test rows to trigger the stream ───────────────────
INSERT INTO RAW_DB.RAW.supply_chain_raw (
    order_id, order_date, shipping_date,
    days_for_shipping_real, days_for_shipment_scheduled,
    delivery_status, late_delivery_risk, sales,
    order_profit_per_order, market, order_region,
    shipping_mode, customer_segment, product_name,
    category_name, department_name, customer_id,
    customer_fname, customer_lname, customer_country,
    order_country, type, order_status,
    source_file_name, batch_id
)
VALUES
    ('999991','1/15/2024 10:00','1/18/2024 10:00','3','2','Late delivery','1','150.00','25.00','Europe','Western Europe','Standard Class','Consumer','Test Product A','Electronics','Technology','99001','Test','UserA','Germany','Germany','DEBIT','COMPLETE','test_insert','BATCH_002'),
    ('999992','2/20/2024 11:00','2/22/2024 11:00','2','2','Shipping on time','0','200.00','50.00','USCA','South of  USA','Second Class','Corporate','Test Product B','Clothing','Apparel','99002','Test','UserB','United States','United States','PAYMENT','COMPLETE','test_insert','BATCH_002'),
    ('999993','3/10/2024 9:00','3/15/2024 9:00','5','2','Late delivery','1','75.00','-10.00','LATAM','South America','First Class','Home Office','Test Product C','Sports','Fan Shop','99003','Test','UserC','Brazil','Brazil','TRANSFER','PENDING','test_insert','BATCH_002');

-- Confirm stream picked up the new rows
SELECT SYSTEM$STREAM_HAS_DATA('RAW_DB.RAW.raw_supply_chain_stream') AS has_new_data;
-- Expected: TRUE

-- Preview what the stream is tracking
SELECT * FROM RAW_DB.RAW.raw_supply_chain_stream LIMIT 5;


-- ── Manually execute the task ────────────────────────────────
-- In production this fires automatically every 60 min when stream has data
-- For testing we trigger it manually
USE ROLE SYSADMIN;
EXECUTE TASK RAW_DB.RAW.refresh_staging_task;


-- ── Check task run history ───────────────────────────────────
-- Wait 15 seconds then run this
SELECT
    name,
    state,
    error_code,
    error_message,
    completed_time
FROM TABLE(information_schema.task_history(
    task_name => 'refresh_staging_task'
))
ORDER BY scheduled_time DESC
LIMIT 3;
-- Expected: state = SUCCEEDED, error_code = null


-- ── Verify test rows arrived in staging ──────────────────────
SELECT
    order_id,
    order_date,
    is_late,
    delay_severity,
    sales,
    market
FROM STAGING_DB.STAGING.stg_supply_chain
WHERE order_id IN (999991, 999992, 999993);

-- Total should be 180,522 (180,519 original + 3 test rows)
SELECT COUNT(*) AS total_rows FROM STAGING_DB.STAGING.stg_supply_chain;


-- ── Suspend task after testing to save credits ───────────────
ALTER TASK RAW_DB.RAW.refresh_staging_task SUSPEND;
