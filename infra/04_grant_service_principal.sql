-- 04_grant_service_principal.sql: least-privilege Unity Catalog grants for the service principal
-- Run by infra/04_setup_service_principal.sh (or: python scripts/run_sql.py infra/04_grant_service_principal.sql)
-- The service principal is addressed by its application id. Safe to re-run (GRANT is idempotent).

-- 1. See the catalog (no access to other schemas, e.g. default)
GRANT USE CATALOG ON CATALOG {{DATABRICKS_CATALOG}} TO `{{DATABRICKS_SP_CLIENT_ID}}`;

-- 2. Bronze: the PySpark job reads the raw files and writes the Delta tables; dbt reads them
GRANT USE SCHEMA, CREATE TABLE, SELECT, MODIFY ON SCHEMA {{DATABRICKS_CATALOG}}.bronze TO `{{DATABRICKS_SP_CLIENT_ID}}`;

GRANT READ VOLUME ON VOLUME {{DATABRICKS_CATALOG}}.bronze.raw_files TO `{{DATABRICKS_SP_CLIENT_ID}}`;

-- 3. Silver, Gold, test failures: dbt creates and rebuilds its models here
GRANT USE SCHEMA, CREATE TABLE, SELECT, MODIFY ON SCHEMA {{DATABRICKS_CATALOG}}.silver TO `{{DATABRICKS_SP_CLIENT_ID}}`;

GRANT USE SCHEMA, CREATE TABLE, SELECT, MODIFY ON SCHEMA {{DATABRICKS_CATALOG}}.gold TO `{{DATABRICKS_SP_CLIENT_ID}}`;

GRANT USE SCHEMA, CREATE TABLE, SELECT, MODIFY ON SCHEMA {{DATABRICKS_CATALOG}}.test_failures TO `{{DATABRICKS_SP_CLIENT_ID}}`;

-- 4. Check
SHOW GRANTS `{{DATABRICKS_SP_CLIENT_ID}}` ON SCHEMA {{DATABRICKS_CATALOG}}.bronze;
