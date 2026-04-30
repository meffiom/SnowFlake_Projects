-- ============================================================
-- FILE: 03_file_format_and_stage.sql
-- PROJECT: Supply Chain Intelligence Platform
-- PHASE: 1 — Environment Setup
-- DESCRIPTION: Creates named FILE FORMAT and internal STAGE
-- RUN AS: DEVELOPER
-- ============================================================

-- ── Why named FILE FORMAT? ───────────────────────────────────
-- Instead of specifying CSV reading rules in every COPY INTO,
-- we define them once as a named object and reuse by name.
-- If the source format changes, we update one object — not every script.


-- ── Step 1: Set context ──────────────────────────────────────
USE ROLE      DEVELOPER;
USE WAREHOUSE DEV_WH;
USE DATABASE  RAW_DB;
USE SCHEMA    RAW;


-- ── Step 2: Create named FILE FORMAT ─────────────────────────
-- WINDOWS1252 encoding handles Western European special characters
-- (accented letters like é, ñ, ü) common in international supply chain data
CREATE OR REPLACE FILE FORMAT csv_format
    TYPE                          = 'CSV'
    FIELD_DELIMITER               = ','
    RECORD_DELIMITER              = '\n'
    SKIP_HEADER                   = 1          -- Row 1 has column names, skip it
    FIELD_OPTIONALLY_ENCLOSED_BY  = '"'        -- Handles fields like "Smith, John"
    NULL_IF                       = ('NULL', 'null', 'N/A', '')
    EMPTY_FIELD_AS_NULL           = TRUE
    TRIM_SPACE                    = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
    ENCODING                      = 'WINDOWS1252'
    COMMENT                       = 'Standard CSV format for DataCo supply chain files';


-- ── Step 3: Create internal STAGE ────────────────────────────
-- Internal stage = Snowflake-managed file storage
-- No S3 or Azure bucket needed — files upload directly via Snowsight UI
-- Think of it as the post office sorting room before COPY INTO delivers to tables
CREATE OR REPLACE STAGE raw_stage
    FILE_FORMAT = csv_format
    COMMENT     = 'Landing zone for raw DataCo CSV files';


-- ── Step 4: Verify ───────────────────────────────────────────
SHOW STAGES IN SCHEMA RAW_DB.RAW;

-- After uploading the CSV via Snowsight UI, run this to confirm:
LIST @RAW_DB.RAW.raw_stage;
-- Should show: DataCoSupplyChainDataset.csv at ~91MB
