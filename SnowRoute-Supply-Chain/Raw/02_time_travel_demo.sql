-- ============================================================
-- FILE: 02_time_travel_demo.sql
-- PROJECT: Supply Chain Intelligence Platform
-- PHASE: 2 — Raw Data Ingestion
-- DESCRIPTION: Demonstrates Snowflake Time Travel feature
-- RUN AS: DEVELOPER
-- ============================================================

-- ── What is Time Travel? ─────────────────────────────────────
-- Snowflake retains historical snapshots of every table for up to
-- 90 days (Enterprise edition). You can query any past state using
-- AT (TIMESTAMP) or BEFORE (STATEMENT) syntax.
-- This means accidentally deleted data can be recovered without backups.
-- Available on Enterprise edition — which is what this project uses.


-- ── Step 1: Record timestamp BEFORE the delete ───────────────
-- Save this value — you will need it in Step 3
SELECT CURRENT_TIMESTAMP() AS before_delete_timestamp;

-- Confirm full row count before deleting
SELECT COUNT(*) AS rows_before FROM RAW_DB.RAW.supply_chain_raw;
-- Expected: 180,519


-- ── Step 2: Intentionally delete rows ────────────────────────
-- Simulates an accidental data loss scenario in production
DELETE FROM RAW_DB.RAW.supply_chain_raw
WHERE market = 'Europe';

-- Confirm rows were removed
SELECT COUNT(*) AS rows_after_delete FROM RAW_DB.RAW.supply_chain_raw;
-- Expected: less than 180,519


-- ── Step 3: Query data as it was BEFORE the delete ───────────
-- Replace the timestamp below with what Step 1 returned
-- Snowflake reads the historical snapshot — deleted rows reappear
SELECT COUNT(*) AS rows_in_past
FROM RAW_DB.RAW.supply_chain_raw
AT (TIMESTAMP => '2026-04-15 07:26:12'::TIMESTAMP_NTZ);
-- Expected: 180,519 — as if the delete never happened


-- ── Step 4: Restore the deleted rows ─────────────────────────
-- Use Time Travel query as the INSERT source to bring data back
INSERT INTO RAW_DB.RAW.supply_chain_raw
SELECT *
FROM RAW_DB.RAW.supply_chain_raw
AT (TIMESTAMP => '2026-04-15 07:26:12'::TIMESTAMP_NTZ)
WHERE market = 'Europe';

-- Confirm full count is restored
SELECT COUNT(*) AS rows_restored FROM RAW_DB.RAW.supply_chain_raw;
-- Expected: 180,519


-- ── Alternative: Time Travel using Statement ID ───────────────
-- Find your DELETE statement Query ID in:
-- Snowsight → Monitoring → Query History → find the DELETE → copy Query ID
-- Then run:
-- SELECT COUNT(*)
-- FROM RAW_DB.RAW.supply_chain_raw
-- BEFORE (STATEMENT => 'paste-your-query-id-here');
