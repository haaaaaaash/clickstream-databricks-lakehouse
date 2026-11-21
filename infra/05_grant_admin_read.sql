-- 05_grant_admin_read.sql: read access for the admin user on all tables in the catalog
-- Why: jobs and dbt run as the service principal, which then owns the tables it creates.
-- Workspace admins get no automatic SELECT on them in Unity Catalog.
-- Granted on the catalog, so it is inherited by all schemas and future tables (silver, gold).
-- Usage: python scripts/run_sql.py infra/05_grant_admin_read.sql
-- References:
--   Privileges and inheritance: https://learn.microsoft.com/azure/databricks/data-governance/unity-catalog/manage-privileges/privileges
--   GRANT:                      https://learn.microsoft.com/azure/databricks/sql/language-manual/security-grant

GRANT USE CATALOG, USE SCHEMA, SELECT ON CATALOG {{DATABRICKS_CATALOG}} TO `{{DATABRICKS_ADMIN_USER}}`;
