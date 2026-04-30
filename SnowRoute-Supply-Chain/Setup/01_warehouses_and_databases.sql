-- ============================================================
-- FILE: 01_warehouses_and_databases.sql
-- PROJECT: Supply Chain Intelligence Platform
-- PHASE: 1 — Environment Setup
-- DESCRIPTION: Creates virtual warehouses, databases, and schemas
-- RUN AS: SYSADMIN
-- ============================================================


-- ── Step 1: Switch to SYSADMIN role ─────────────────────────
USE ROLE SYSADMIN;


-- ── Step 2: Create Virtual Warehouses ───────────────────────
-- DEV_WH: Used for development, exploration, and lightweight queries
-- AUTO_SUSPEND = 60 seconds to save credits when idle
CREATE WAREHOUSE IF NOT EXISTS DEV_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND   = 60
    AUTO_RESUME    = TRUE
    COMMENT        = 'Development warehouse — auto-suspends after 60 seconds idle';

-- PROD_WH: Used for heavy loads like COPY INTO and Task runs
-- AUTO_SUSPEND = 120 seconds — slightly longer for production jobs
CREATE WAREHOUSE IF NOT EXISTS PROD_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND   = 120
    AUTO_RESUME    = TRUE
    COMMENT        = 'Production warehouse — used for COPY INTO and Task runs';


-- ── Step 3: Set active warehouse ────────────────────────────
USE WAREHOUSE DEV_WH;


-- ── Step 4: Create Databases ─────────────────────────────────
-- Three-layer medallion architecture:
-- RAW_DB      → untouched source data (Bronze layer)
-- STAGING_DB  → cleaned and enriched data (Silver layer)
-- ANALYTICS_DB → star schema, KPI views, Snowpark outputs (Gold layer)

CREATE DATABASE IF NOT EXISTS RAW_DB;
CREATE DATABASE IF NOT EXISTS STAGING_DB;
CREATE DATABASE IF NOT EXISTS ANALYTICS_DB;


-- ── Step 5: Create Schemas ───────────────────────────────────
CREATE SCHEMA IF NOT EXISTS RAW_DB.RAW;
CREATE SCHEMA IF NOT EXISTS STAGING_DB.STAGING;
CREATE SCHEMA IF NOT EXISTS ANALYTICS_DB.ANALYTICS;
CREATE SCHEMA IF NOT EXISTS ANALYTICS_DB.SNOWPARK;   -- Snowpark Python outputs


-- ── Step 6: Verify ──────────────────────────────────────────
SHOW DATABASES;
SHOW WAREHOUSES;
