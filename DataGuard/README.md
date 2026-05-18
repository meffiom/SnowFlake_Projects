# DataGuard Stack — Automated Data Quality Pipeline
## Overview

An end-to-end automated data quality monitoring pipeline built on the **Maven Analytics Cafe Rewards dataset** — 17,000 customers and 306,000+ events. This project replicates how production data engineering teams catch and alert on data quality issues before they reach business users.

---

## Tech Stack

| Tool | Purpose |
|---|---|
| **Snowflake** | Cloud data warehouse — stores raw and transformed data |
| **dbt** | Data transformation — cleans and models raw data into business-ready tables |
| **Great Expectations** | Data quality — 13 automated checks across 3 tables |
| **Slack API** | Alerting — fires a message to a dedicated channel when checks fail |
| **Windows Task Scheduler** | Orchestration — runs the full pipeline daily automatically |

---

## Project Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        RAW DATA                             │
│         customers.csv │ events.csv │ offers.csv             │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      SNOWFLAKE                              │
│              CAFE_REWARDS.RAW schema                        │
│        CUSTOMERS │ EVENTS │ OFFERS                          │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                     dbt STAGING LAYER                       │
│                                                             │
│  stg_customers     stg_events        stg_offers             │
│  ─────────────     ──────────        ─────────              │
│  Fix age=118       Parse nested      Rename cols            │
│  Clean gender      value column      for clarity            │
│  Format dates      Extract IDs                              │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      dbt MART LAYER                         │
│                                                             │
│   mart_offer_funnel          mart_customer_segments         │
│   ─────────────────          ───────────────────────        │
│   Received → Viewed          Age bands & income groups      │
│   → Completed rates          + transaction history          │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│               GREAT EXPECTATIONS VALIDATION                 │
│                                                             │
│   ✓ Row counts above minimum threshold                      │
│   ✓ Age values between 18–100 (catches sentinel 118)        │
│   ✓ Null rates below 15% for gender and income              │
│   ✓ customer_id uniqueness                                  │
│   ✓ Completion and view rates between 0–100%                │
│   ✓ Income segments only contain known values               │
└───────────────────────────┬─────────────────────────────────┘
                            │
               ┌────────────┴────────────┐
               ▼                         ▼
        ✅ ALL PASSED              ❌ CHECKS FAILED
        Slack success             Slack alert fired
        notification              with failure details
```

---
## dbt Models

### Staging Layer
| Model | Description |
|---|---|
| `stg_customers` | Cleans raw customer data — converts age sentinel value 118 → null, standardises gender codes M/F/O, parses membership date, calculates membership tenure in days |
| `stg_events` | Parses the raw nested value column into separate `offer_id` and `transaction_amount` fields, classifies event types |
| `stg_offers` | Renames columns for business readability (difficulty → min_spend, reward → reward_amount) |

### Mart Layer
| Model | Description |
|---|---|
| `mart_offer_funnel` | Calculates per-offer metrics: received count, viewed count, completed count, view rate %, completion rate % |
| `mart_customer_segments` | Segments customers into age bands (Under 30, 30–44, 45–59, 60+) and income bands (Low, Medium, High), joined with transaction history |

---

## Data Quality Checks

| Table | Check | Why It Matters |
|---|---|---|
| stg_customers | Row count > 0 | Catches empty loads |
| stg_customers | Age between 18–100 | Catches sentinel value 118 |
| stg_customers | Gender null rate < 15% | Catches data spikes |
| stg_customers | Income null rate < 15% | Catches data spikes |
| stg_customers | customer_id unique | Catches duplicate records |
| mart_offer_funnel | Exactly 10 rows | Catches missing offers |
| mart_offer_funnel | Completion rate 0–100% | Catches calculation errors |
| mart_offer_funnel | View rate 0–100% | Catches calculation errors |
| mart_offer_funnel | Received count > 0 | Catches missing event data |
| mart_customer_segments | Row count 16k–18k | Catches join issues |
| mart_customer_segments | Valid income segments | Catches unexpected values |
| mart_customer_segments | Valid age segments | Catches unexpected values |
| mart_customer_segments | Total spend >= 0 | Catches negative amounts |

---

## Key Findings

- Best performing offer: **97.13% view rate, 71.54% completion rate**
- 2 offers had **0% completion rate** despite thousands of views — identified as informational offers with no reward to complete
- **12.8% of customers** (2,175 rows) had unknown demographics stored as age=118 — a sentinel value caught and cleaned in the staging layer
- Lowest performing offer had only a **37.65% view rate** — customers not engaging with this campaign

---

## How to Run

```bash
# 1. Activate virtual environment
dataguard-env\Scripts\activate

# 2. Run dbt models
cd cafe_rewards
dbt run

# 3. Run quality checks and send Slack alert
cd ..
python validate.py
```
