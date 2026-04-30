-- ============================================================
-- FILE: 01_raw_table_and_copy_into.sql
-- PROJECT: Supply Chain Intelligence Platform
-- PHASE: 2 — Raw Data Ingestion
-- DESCRIPTION: Creates RAW table and loads data from stage
-- RUN AS: DEVELOPER (use PROD_WH for faster load)
-- DATASET: DataCo Smart Supply Chain — 180,519 rows
-- SOURCE: kaggle.com/datasets/shashwatwork/dataco-smart-supply-chain-for-big-data-analysis
-- ============================================================

-- ── Key design decisions ─────────────────────────────────────
-- 1. ALL columns are VARCHAR in the RAW layer — no type casting here.
--    Type casting happens in STAGING. This means the raw load never
--    fails due to format changes in the source system.
-- 2. Three metadata columns added: ingestion_timestamp, source_file_name, batch_id
--    These are standard in production pipelines and show engineering awareness.
-- 3. ON_ERROR = CONTINUE means bad rows are skipped, not the whole load.


-- ── Step 1: Set context ──────────────────────────────────────
USE ROLE      DEVELOPER;
USE WAREHOUSE PROD_WH;      -- Use PROD_WH for bulk loads — faster than DEV_WH
USE DATABASE  RAW_DB;
USE SCHEMA    RAW;


-- ── Step 2: Create RAW table ─────────────────────────────────
-- Every column is VARCHAR — preserve source data exactly as received
CREATE OR REPLACE TABLE RAW_DB.RAW.supply_chain_raw (
    type                          VARCHAR,
    days_for_shipping_real        VARCHAR,
    days_for_shipment_scheduled   VARCHAR,
    benefit_per_order             VARCHAR,
    sales_per_customer            VARCHAR,
    delivery_status               VARCHAR,
    late_delivery_risk            VARCHAR,
    category_id                   VARCHAR,
    category_name                 VARCHAR,
    customer_city                 VARCHAR,
    customer_country              VARCHAR,
    customer_email                VARCHAR,
    customer_fname                VARCHAR,
    customer_id                   VARCHAR,
    customer_lname                VARCHAR,
    customer_password             VARCHAR,
    customer_segment              VARCHAR,
    customer_state                VARCHAR,
    customer_street               VARCHAR,
    customer_zipcode              VARCHAR,
    department_id                 VARCHAR,
    department_name               VARCHAR,
    latitude                      VARCHAR,
    longitude                     VARCHAR,
    market                        VARCHAR,
    order_city                    VARCHAR,
    order_country                 VARCHAR,
    order_customer_id             VARCHAR,
    order_date                    VARCHAR,   -- Kept as VARCHAR — cast in STAGING
    order_id                      VARCHAR,
    order_item_cardprod_id        VARCHAR,
    order_item_discount           VARCHAR,
    order_item_discount_rate      VARCHAR,
    order_item_id                 VARCHAR,
    order_item_product_price      VARCHAR,
    order_item_profit_ratio       VARCHAR,
    order_item_quantity           VARCHAR,
    sales                         VARCHAR,
    order_item_total              VARCHAR,
    order_profit_per_order        VARCHAR,
    order_region                  VARCHAR,
    order_state                   VARCHAR,
    order_status                  VARCHAR,
    order_zipcode                 VARCHAR,
    product_card_id               VARCHAR,
    product_category_id           VARCHAR,
    product_description           VARCHAR,
    product_image                 VARCHAR,
    product_name                  VARCHAR,
    product_price                 VARCHAR,
    product_status                VARCHAR,
    shipping_date                 VARCHAR,   -- Kept as VARCHAR — cast in STAGING
    shipping_mode                 VARCHAR,
    -- Metadata columns (production pattern — tracks when/where data came from)
    ingestion_timestamp           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    source_file_name              VARCHAR,
    batch_id                      VARCHAR
);


-- ── Step 3: Load data from stage using COPY INTO ─────────────
-- COPY INTO is Snowflake's bulk loader — processes 180k rows in seconds
-- Much faster than INSERT — optimised for large file ingestion
COPY INTO RAW_DB.RAW.supply_chain_raw (
    type, days_for_shipping_real, days_for_shipment_scheduled,
    benefit_per_order, sales_per_customer, delivery_status,
    late_delivery_risk, category_id, category_name,
    customer_city, customer_country, customer_email,
    customer_fname, customer_id, customer_lname,
    customer_password, customer_segment, customer_state,
    customer_street, customer_zipcode, department_id,
    department_name, latitude, longitude, market,
    order_city, order_country, order_customer_id,
    order_date, order_id, order_item_cardprod_id,
    order_item_discount, order_item_discount_rate,
    order_item_id, order_item_product_price,
    order_item_profit_ratio, order_item_quantity,
    sales, order_item_total, order_profit_per_order,
    order_region, order_state, order_status,
    order_zipcode, product_card_id, product_category_id,
    product_description, product_image, product_name,
    product_price, product_status, shipping_date, shipping_mode,
    source_file_name, batch_id
)
FROM (
    SELECT
        $1,  $2,  $3,  $4,  $5,  $6,  $7,  $8,  $9,  $10,
        $11, $12, $13, $14, $15, $16, $17, $18, $19, $20,
        $21, $22, $23, $24, $25, $26, $27, $28, $29, $30,
        $31, $32, $33, $34, $35, $36, $37, $38, $39, $40,
        $41, $42, $43, $44, $45, $46, $47, $48, $49, $50,
        $51, $52, $53,
        METADATA$FILENAME,     -- Automatically captures the source file name
        'BATCH_001'            -- Batch identifier for this load run
    FROM @RAW_DB.RAW.raw_stage
)
FILE_FORMAT = (FORMAT_NAME = 'RAW_DB.RAW.csv_format')
ON_ERROR    = 'CONTINUE';     -- Skip bad rows — don't fail the whole load


-- ── Step 4: Validate the load ────────────────────────────────
-- Production practice: always verify after loading — never assume success

-- Total row count — should be 180,519
SELECT COUNT(*) AS total_rows
FROM RAW_DB.RAW.supply_chain_raw;

-- Load history — shows rows loaded, errors, file name
-- This is the delivery receipt for your COPY INTO
SELECT
    file_name,
    status,
    row_count,
    row_parsed,
    error_count
FROM information_schema.load_history
WHERE table_name = 'SUPPLY_CHAIN_RAW'
ORDER BY last_load_time DESC
LIMIT 5;

-- Preview first 5 rows
SELECT * FROM RAW_DB.RAW.supply_chain_raw LIMIT 5;
