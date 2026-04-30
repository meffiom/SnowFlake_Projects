# SnowRoute-Supply-Chain
End-to-end Snowflake supply chain platform — Medallion architecture, Streams, Tasks, Snowpark Python, Power BI

# SnowRoute — Supply Chain Intelligence Platform

> End-to-end Snowflake data platform for supply chain analytics.
> Built to answer why 57% of all orders arrive late and which 
> shipping routes carry the highest operational risk.

---

## Project Overview

I built this project to take a raw 180,000-row supply chain 
CSV file and turn it into something a business stakeholder 
can sit in front of and make decisions from. The platform 
covers the full stack — from raw ingestion through to a 
four-page Power BI dashboard — using Snowflake-native tools 
throughout.

| Property | Detail |
|----------|--------|
| **Dataset** | DataCo Smart Supply Chain — 180,519 rows (Kaggle) |
| **Platform** | Snowflake Enterprise (AWS us-east-1) |
| **Dashboard** | Power BI Desktop — 4 pages |
| **Architecture** | Medallion — Bronze → Silver → Gold |

---

## Key Findings

| Metric | Value | Status |
|--------|-------|--------|
| Total Revenue | $36.78M | ✅ |
| Total Orders | 66,000 | ✅ |
| Late Delivery Rate | 57.28% | 🔴 |
| On-Time Rate | 42.72% | 🔴 |
| Avg Profit Margin | 10.83% | 🟡 |
| Unique Customers | 21K | ✅ |
| Avg Risk Score | 56.10 / 100 | 🔴 |
| Minor Delay Revenue | $19.6M | 🔴 |
| First Class Late Rate | 100% | 🔴 |

**Critical finding:** First Class shipping — the premium 
delivery tier — has a 100% late rate across all 27,814 
orders. Not a single First Class shipment arrived on time.

**Revenue finding:** Minor Delay orders (1–3 days late) 
account for $19.6M in revenue — more than On Time orders 
at $15.8M. The business is processing more high-value 
orders through the delayed channel than the on-time channel.

---

## Architecture

The platform uses a three-layer medallion architecture 
inside Snowflake. Each layer has one responsibility.

CSV File (91MB)
│
│  COPY INTO + Internal Stage
▼
┌─────────────────────────────────┐
│  BRONZE — RAW_DB.RAW            │
│  All columns loaded as VARCHAR  │
│  Time Travel · Stream · Task    │
└────────────────┬────────────────┘
│  Stream + Task (automatic)
▼
┌─────────────────────────────────┐
│  SILVER — STAGING_DB.STAGING    │
│  TRY_CAST · date parsing        │
│  delivery_delay_days · is_late  │
│  delay_severity · profit_margin │
└────────────────┬────────────────┘
│  SQL build
▼
┌─────────────────────────────────┐
│  GOLD — ANALYTICS_DB            │
│  Star schema · 5 KPI views      │
│  Materialized View              │
│  Snowpark risk scores           │
│  Python UDF · Dynamic Table     │
└────────────────┬────────────────┘
│  Power BI connector
▼
4-page Dashboard

---


## Tech Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| Cloud warehouse | Snowflake Enterprise | All storage, compute, orchestration |
| Ingestion | COPY INTO + Internal Stage | Bulk load 180k rows |
| Transformation | Snowflake SQL | Type casting, enrichment, star schema |
| CDC | Snowflake Streams | Detects new inserts automatically |
| Orchestration | Snowflake Tasks | Fires pipeline when stream has data |
| Data recovery | Time Travel | Rows restored using AT TIMESTAMP |
| Advanced analytics | Snowpark Python | Risk scoring inside Snowflake |
| Python UDF | Snowpark UDF | classify_delay_severity() from SQL |
| Auto-refresh | Dynamic Tables | Self-managing 1-hour target lag |
| Performance | Materialized View | Pre-computes shipping aggregation |
| Access control | RBAC | BI_READER isolated to ANALYTICS_DB |
| Dashboard | Power BI Desktop | 4 pages · 10 DAX measures |

---

## Snowflake Features Demonstrated

| Feature | How it was used |
|---------|----------------|
| **Time Travel** | Deleted rows restored using AT (TIMESTAMP) — no backup needed |
| **Streams** | APPEND_ONLY stream captures every insert automatically |
| **Tasks** | Fires when SYSTEM$STREAM_HAS_DATA() is TRUE — no Airflow needed |
| **Materialized Views** | Pre-computes shipping performance for faster dashboard queries |
| **Snowpark Python** | Composite risk scoring runs inside the warehouse |
| **Python UDF** | classify_delay_severity() registered permanently in Snowflake |
| **Dynamic Tables** | Auto-refreshes risk summary within 1-hour target lag |
| **RBAC** | BI_READER role cannot access RAW or STAGING databases |
| **QUALIFY + ROW_NUMBER** | Deduplication pattern on all five dimension tables |

---

## Repository Structure

snowroute-supply-chain/
│
├── setup/
│   ├── 01_warehouses_and_databases.sql
│   ├── 02_roles_and_permissions.sql
│   └── 03_file_format_and_stage.sql
│
├── raw/
│   ├── 01_raw_table_and_copy_into.sql
│   └── 02_time_travel_demo.sql
│
├── staging/
│   └── 01_staging_layer.sql
│
├── pipeline/
│   └── 01_streams_and_tasks.sql
│
├── analytics/
│   ├── 01_dimension_tables.sql
│   ├── 02_fact_table.sql
│   └── 03_kpi_views_and_materialized_view.sql
│
├── docs/
│   ├── medallion_architecture.jpg
│   ├── dashboard_page1.png
│   ├── dashboard_page2.png
│   ├── dashboard_page3.png
│   └── dashboard_page4.png
└── SnowRoute.pbix

---

## How to Reproduce

### Prerequisites
- Snowflake free trial — trial.snowflake.com
  (Enterprise · AWS · us-east-1 · $400 credit · no card needed)
- DataCo dataset from Kaggle (free)
  kaggle.com/datasets/shashwatwork/dataco-smart-supply-chain-for-big-data-analysis
- Power BI Desktop (free from Microsoft)

### Steps
1. Sign up for Snowflake Enterprise trial
2. Run SQL scripts in this order:
   - setup/ → raw/ → staging/ → pipeline/ → analytics/ → snowpark/
3. Upload DataCoSupplyChainDataset.csv to Snowflake internal 
   stage via Snowsight — Ingestion → Add Data → Load files 
   into stage → RAW_DB.RAW.RAW_STAGE
4. Run COPY INTO from raw/01_raw_table_and_copy_into.sql
5. Open dashboard/supply_chain_report.pbix in Power BI Desktop

### Estimated cost
The entire project uses approximately $5–10 of the 
$400 free trial credit when using XS and S warehouses 
with AUTO_SUSPEND enabled.

---

## Key Design Decisions

**1. All RAW columns loaded as VARCHAR**
Type casting happens in STAGING only. This means the 
raw load never fails when source formats change — 
a production best practice.

**2. Streams instead of Airflow**
Snowflake Streams and Tasks replace an external 
orchestrator entirely. The task fires only when 
SYSTEM$STREAM_HAS_DATA() returns TRUE — saving credits.

**3. No JOIN in fact_orders**
Joining dim_shipping (92 rows per route) to 180k fact 
rows caused a 123 million row cartesian explosion. 
Shipping columns kept directly in fact_orders instead.

**4. dim_shipping_mode bridge table**
A four-row table with one row per shipping mode resolves 
Many-to-Many relationships in Power BI caused by route-
level granularity in dim_shipping and shipping_risk_scores.

**5. Snowpark over external Python**
Risk scoring runs inside Snowflake using the Snowpark 
DataFrame API. Data never leaves the warehouse.

---

## What Went Wrong

Three real problems encountered and fixed during the build.

**Encoding error — 66,332 rows failed**
Special characters in country names caused UTF-8 
validation failures. Fixed by adding ENCODING = 
'WINDOWS1252' to the FILE FORMAT definition.

**123 million row cartesian explosion**
A JOIN on dim_shipping caused 180k × 92 = 123M rows. 
Query ran for 9 minutes before being cancelled. Fixed 
by removing the JOIN and keeping shipping columns 
directly in fact_orders.

**Power BI Many-to-Many relationships**
dim_shipping had 23 duplicate rows per shipping mode 
making Many-to-One impossible. Fixed by creating 
dim_shipping_mode with exactly 4 rows as a bridge table.

---

## Dataset

DataCo Smart Supply Chain for Big Data Analysis
kaggle.com/datasets/shashwatwork/dataco-smart-supply-chain-for-big-data-analysis
180,519 rows · Orders, shipments, customers, products,
delivery status · Free to download

## Dashboard
<img width="1170" height="642" alt="Screenshot 2026-04-23 021715" src="https://github.com/user-attachments/assets/2ba63a6a-e59a-4afe-8e22-4974a8d82dec" />

<img width="1135" height="640" alt="Screenshot 2026-04-23 021742" src="https://github.com/user-attachments/assets/c325a0d3-978c-48c8-a30b-5eb3956d3105" />

<img width="1125" height="634" alt="Screenshot 2026-04-23 021841" src="https://github.com/user-attachments/assets/f91dfe02-9ca6-4eb7-8b84-9a2c0a975faa" />

<img width="1119" height="628" alt="Screenshot 2026-04-23 021858" src="https://github.com/user-attachments/assets/0c75ed51-5cc6-4ccc-9590-e2153f51efaa" />

