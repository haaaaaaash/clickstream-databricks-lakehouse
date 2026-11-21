-- 06_check_bronze_counts.sql: compares the Bronze row counts with the counts from the EDA
-- Run (from the repo root): python scripts/run_sql.py infra/06_check_bronze_counts.sql
-- Every row must show status OK.

SELECT
  table_name,
  actual_rows,
  expected_rows,
  CASE WHEN actual_rows = expected_rows THEN 'OK' ELSE 'MISMATCH' END AS status
FROM (
  SELECT 'customers'   AS table_name, (SELECT COUNT(*) FROM {{DATABRICKS_CATALOG}}.bronze.customers)   AS actual_rows, 20000  AS expected_rows
  UNION ALL
  SELECT 'events',                    (SELECT COUNT(*) FROM {{DATABRICKS_CATALOG}}.bronze.events),                   760958
  UNION ALL
  SELECT 'order_items',               (SELECT COUNT(*) FROM {{DATABRICKS_CATALOG}}.bronze.order_items),              59163
  UNION ALL
  SELECT 'orders',                    (SELECT COUNT(*) FROM {{DATABRICKS_CATALOG}}.bronze.orders),                   33580
  UNION ALL
  SELECT 'products',                  (SELECT COUNT(*) FROM {{DATABRICKS_CATALOG}}.bronze.products),                 1197
  UNION ALL
  SELECT 'reviews',                   (SELECT COUNT(*) FROM {{DATABRICKS_CATALOG}}.bronze.reviews),                  10780
  UNION ALL
  SELECT 'sessions',                  (SELECT COUNT(*) FROM {{DATABRICKS_CATALOG}}.bronze.sessions),                 120000
)
ORDER BY table_name;
