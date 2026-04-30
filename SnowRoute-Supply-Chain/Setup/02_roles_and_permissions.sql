-- ============================================================
-- FILE: 02_roles_and_permissions.sql
-- PROJECT: Supply Chain Intelligence Platform
-- PHASE: 1 — Environment Setup
-- DESCRIPTION: Creates roles and grants permissions (RBAC setup)
-- RUN AS: SECURITYADMIN then SYSADMIN
-- ============================================================

-- ── Why three roles? ─────────────────────────────────────────
-- ACCOUNTADMIN  → Account owner — never used for daily work
-- SYSADMIN      → Creates infrastructure — warehouses, databases
-- DEVELOPER     → Day-to-day work — read/write all three databases
-- BI_READER     → Dashboard connection — read-only on ANALYTICS_DB only
--                 If BI_READER credentials leak, attacker can only
--                 read pre-aggregated analytics data — not raw data


-- ── Step 1: Switch to SECURITYADMIN to manage roles ─────────
USE ROLE SECURITYADMIN;


-- ── Step 2: Create custom roles ──────────────────────────────
CREATE ROLE IF NOT EXISTS DEVELOPER;
CREATE ROLE IF NOT EXISTS BI_READER;


-- ── Step 3: Add roles to hierarchy ───────────────────────────
-- Best practice: all custom roles roll up to SYSADMIN
GRANT ROLE DEVELOPER TO ROLE SYSADMIN;
GRANT ROLE BI_READER  TO ROLE SYSADMIN;


-- ── Step 4: Assign roles to your user ────────────────────────
-- Replace AHSANV032 with your Snowflake username
-- Run SELECT CURRENT_USER(); to confirm your username
GRANT ROLE DEVELOPER TO USER "AHSANV032";
GRANT ROLE BI_READER  TO USER "AHSANV032";


-- ── Step 5: Switch to SYSADMIN to grant warehouse access ─────
USE ROLE SYSADMIN;

-- DEVELOPER gets both warehouses for full flexibility
GRANT USAGE ON WAREHOUSE DEV_WH  TO ROLE DEVELOPER;
GRANT USAGE ON WAREHOUSE PROD_WH TO ROLE DEVELOPER;

-- BI_READER only gets DEV_WH — no need for production compute
GRANT USAGE ON WAREHOUSE DEV_WH TO ROLE BI_READER;


-- ── Step 6: Grant database access to DEVELOPER ───────────────
-- DEVELOPER needs full access to all three databases to build the pipeline
GRANT ALL ON DATABASE RAW_DB       TO ROLE DEVELOPER;
GRANT ALL ON DATABASE STAGING_DB   TO ROLE DEVELOPER;
GRANT ALL ON DATABASE ANALYTICS_DB TO ROLE DEVELOPER;

GRANT ALL ON ALL SCHEMAS IN DATABASE RAW_DB       TO ROLE DEVELOPER;
GRANT ALL ON ALL SCHEMAS IN DATABASE STAGING_DB   TO ROLE DEVELOPER;
GRANT ALL ON ALL SCHEMAS IN DATABASE ANALYTICS_DB TO ROLE DEVELOPER;


-- ── Step 7: Grant read-only access to BI_READER ──────────────
-- BI_READER can only see ANALYTICS_DB — never touches RAW or STAGING
GRANT USAGE  ON DATABASE ANALYTICS_DB                    TO ROLE BI_READER;
GRANT USAGE  ON ALL SCHEMAS IN DATABASE ANALYTICS_DB     TO ROLE BI_READER;
GRANT SELECT ON ALL TABLES IN DATABASE ANALYTICS_DB      TO ROLE BI_READER;
GRANT SELECT ON ALL VIEWS  IN DATABASE ANALYTICS_DB      TO ROLE BI_READER;


-- ── Step 8: Verify ──────────────────────────────────────────
SHOW ROLES;
