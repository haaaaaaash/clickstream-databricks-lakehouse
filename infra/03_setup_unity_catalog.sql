-- 03_setup_unity_catalog.sql: medallion schemas + a volume for the raw CSV files
-- Run (from the repo root): python scripts/run_sql.py infra/03_setup_unity_catalog.sql
-- Uses the workspace catalog that Unity Catalog created with the workspace (DATABRICKS_CATALOG in .env).
-- Safe to re-run (IF NOT EXISTS).

-- 1. One schema per layer
CREATE SCHEMA IF NOT EXISTS {{DATABRICKS_CATALOG}}.bronze
  COMMENT 'Bronze: raw CSVs landed as Delta tables by PySpark (faithful copy + _ingested_at, _source_file)';

CREATE SCHEMA IF NOT EXISTS {{DATABRICKS_CATALOG}}.silver
  COMMENT 'Silver: dbt dim_* and fct_* models (clean, joined, tested)';

CREATE SCHEMA IF NOT EXISTS {{DATABRICKS_CATALOG}}.gold
  COMMENT 'Gold: dbt mart_* models (business-ready metrics)';

CREATE SCHEMA IF NOT EXISTS {{DATABRICKS_CATALOG}}.test_failures
  COMMENT 'Rows returned by failing dbt tests (store_failures)';

-- 2. Managed volume for the raw CSV files (path: /Volumes/<catalog>/bronze/raw_files/)
CREATE VOLUME IF NOT EXISTS {{DATABRICKS_CATALOG}}.bronze.raw_files
  COMMENT 'Raw CSV files uploaded from data/raw/ (infra/05_upload_raw_data.sh)';

-- 3. Check
SHOW SCHEMAS IN {{DATABRICKS_CATALOG}};

SHOW VOLUMES IN {{DATABRICKS_CATALOG}}.bronze;
