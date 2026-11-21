# Compute configuration

Applied by `infra/02_setup_compute.sh`. Edit the JSON, then re-run the script.

| File | What it configures | Reference |
|---|---|---|
| `sql_warehouse.json` | SQL warehouse used by dbt (size, auto-stop, serverless) | [SQL Warehouses API: create](https://docs.databricks.com/api/azure/workspace/warehouses/create) |
| `cluster_policy.json` | Rules for the PySpark job cluster (runtime, node type, single node, on-demand, max DBU/hour) | [Compute policy reference](https://learn.microsoft.com/azure/databricks/admin/clusters/policy-definition) · [Cluster Policies API](https://docs.databricks.com/api/azure/workspace/clusterpolicies/create) |

Runtime `15.4.x-scala2.12` = [Databricks Runtime 15.4 LTS](https://learn.microsoft.com/azure/databricks/release-notes/runtime/15.4lts) (Spark 3.5, Python 3.11).

Notes:
- No `autotermination_minutes` in the policy: job clusters stop automatically when the run ends, and the API rejects the setting for them.
- No `project` tag: the workspace tag (`--tags` in `01_create_workspace.sh`) is copied to every cluster as a default tag; setting the same key again causes a conflict.
- Node type `Standard_DS3_v2` (DSv2 family, 4 vCPU, 14 GB) and on-demand VMs: the subscription has no vCPU quota for newer families (e.g. DDSv5) and only 3 spot vCPUs. Check with `az vm list-usage --location germanywestcentral -o table`.
