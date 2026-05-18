import great_expectations as gx

CONNECTION_STRING = (
    "snowflake://AHSANAHMAD:Dataguard12345@imucvan-tv39369/"
    "CAFE_REWARDS/RAW?warehouse=DATAGUARD_WH&role=ACCOUNTADMIN"
)

def validate_table(context, datasource, table_name, suite_name, expectations):
    asset = datasource.add_table_asset(name=table_name, table_name=table_name)
    batch_def = asset.add_batch_definition_whole_table(f"{table_name}_batch")
    suite = gx.ExpectationSuite(name=suite_name)
    suite = context.suites.add(suite)
    for exp in expectations:
        suite.add_expectation(exp)
    validation_def = context.validation_definitions.add(
        gx.ValidationDefinition(name=f"{table_name}_validation",
            data=batch_def, suite=suite)
    )
    result = validation_def.run()
    return result.success

def run_validations():
    context = gx.get_context()
    datasource = context.data_sources.add_sql(
        name="snowflake_datasource",
        connection_string=CONNECTION_STRING,
    )
    results = []

    # 1. stg_customers
    print("\nValidating stg_customers...")
    passed = validate_table(context, datasource, "stg_customers", "customers_suite", [
        gx.expectations.ExpectTableRowCountToBeBetween(min_value=1),
        gx.expectations.ExpectColumnValuesToBeBetween(column="age", min_value=18, max_value=100, mostly=0.99),
        gx.expectations.ExpectColumnValuesToNotBeNull(column="gender", mostly=0.85),
        gx.expectations.ExpectColumnValuesToNotBeNull(column="income", mostly=0.85),
        gx.expectations.ExpectColumnValuesToBeUnique(column="customer_id"),
    ])
    results.append(("stg_customers", passed))
    print(f"   {'PASSED' if passed else 'FAILED'}")

    # 2. mart_offer_funnel
    print("\nValidating mart_offer_funnel...")
    passed = validate_table(context, datasource, "mart_offer_funnel", "funnel_suite", [
        gx.expectations.ExpectTableRowCountToEqual(value=10),
        gx.expectations.ExpectColumnValuesToBeBetween(column="completion_rate_pct", min_value=0, max_value=100),
        gx.expectations.ExpectColumnValuesToBeBetween(column="view_rate_pct", min_value=0, max_value=100),
        gx.expectations.ExpectColumnValuesToBeBetween(column="received_count", min_value=1),
    ])
    results.append(("mart_offer_funnel", passed))
    print(f"   {'PASSED' if passed else 'FAILED'}")

    # 3. mart_customer_segments
    print("\nValidating mart_customer_segments...")
    passed = validate_table(context, datasource, "mart_customer_segments", "segments_suite", [
        gx.expectations.ExpectTableRowCountToBeBetween(min_value=16000, max_value=18000),
        gx.expectations.ExpectColumnValuesToBeInSet(column="income_segment", value_set=["Low","Medium","High","Unknown"]),
        gx.expectations.ExpectColumnValuesToBeInSet(column="age_segment", value_set=["Under 30","30-44","45-59","60+","Unknown"]),
        gx.expectations.ExpectColumnValuesToBeBetween(column="total_spend", min_value=0),
    ])
    results.append(("mart_customer_segments", passed))
    print(f"   {'PASSED' if passed else 'FAILED'}")

    # Summary
    print("\n" + "="*50)
    print("VALIDATION SUMMARY")
    print("="*50)
    all_passed = True
    for table, p in results:
        print(f"  {table}: {'PASSED' if p else 'FAILED'}")
        if not p:
            all_passed = False
    print("="*50)

    # Send Slack alert
    from slack_alert import send_success, send_alert
    if all_passed:
        send_success()
        print("ALL CHECKS PASSED — Slack notified!")
    else:
        failed_tables = [t for t, p in results if not p]
        send_alert(failed_tables)
        print("SOME CHECKS FAILED — Slack alert sent!")

if __name__ == "__main__":
    run_validations()