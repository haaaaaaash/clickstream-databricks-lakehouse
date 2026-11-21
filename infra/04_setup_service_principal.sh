#!/bin/bash
# 04_setup_service_principal.sh: technical identity for dbt, Airflow and CI (instead of a personal login)
# Usage (from the repo root): bash infra/04_setup_service_principal.sh
# Prerequisite: 02_setup_compute.sh and 03_setup_unity_catalog.sql have run
#
# 1. Entra ID service principal "sp-clickstream" + client secret (valid 1 year), no Azure role
# 2. Added to the Databricks workspace with workspace + SQL access
#    + checks that you have its "Use" role (needed to deploy jobs with run_as; granted once in the UI)
# 3. CAN_USE on the SQL warehouse and the cluster policy
# 4. Least-privilege Unity Catalog grants (infra/04_grant_service_principal.sql)
# 5. Connection test with the service principal's own credentials
# Writes DATABRICKS_SP_CLIENT_ID, DATABRICKS_SP_CLIENT_SECRET and AZURE_TENANT_ID to .env. The secret is never printed.
# Safe to re-run: an existing service principal is reused, its secret is only renewed if .env has none.
set -euo pipefail

# 0. Load .env
if [ ! -f .env ]; then
  echo "ERROR: .env not found. Run from the repo root (see .env.example)."
  exit 1
fi
set -a; source .env; set +a
: "${DATABRICKS_ADMIN_PROFILE:?missing in .env}" "${DATABRICKS_WAREHOUSE_ID:?missing in .env}"
: "${DATABRICKS_CLUSTER_POLICY_ID:?missing in .env}" "${DATABRICKS_WORKSPACE_URL:?missing in .env}"
P="$DATABRICKS_ADMIN_PROFILE"
SP_NAME="sp-clickstream"

set_env() {
  if grep -q "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else echo "$1=$2" >> .env; fi
}
is_placeholder() { [[ -z "$1" || "$1" == 00000000-* || "$1" == "your-secret" ]]; }

echo "1. Entra ID service principal $SP_NAME..."
az account show > /dev/null 2>&1 || az login --use-device-code > /dev/null
az account set --subscription "$AZURE_SUBSCRIPTION_ID"
TENANT_ID=$(az account show --query tenantId -o tsv)
APP_ID=$(az ad sp list --display-name "$SP_NAME" --query "[0].appId" -o tsv)
if [ -z "$APP_ID" ]; then
  # No --role: the service principal gets no rights in Azure, only in Databricks
  CREATED=$(az ad sp create-for-rbac --name "$SP_NAME" --years 1 -o json)
  APP_ID=$(echo "$CREATED" | python3 -c "import sys, json; print(json.load(sys.stdin)['appId'])")
  SECRET=$(echo "$CREATED" | python3 -c "import sys, json; print(json.load(sys.stdin)['password'])")
  echo "   created (app id: $APP_ID)"
elif is_placeholder "${DATABRICKS_SP_CLIENT_SECRET:-}" || [ "${DATABRICKS_SP_CLIENT_ID:-}" != "$APP_ID" ]; then
  SECRET=$(az ad app credential reset --id "$APP_ID" --display-name clickstream --years 1 --append --query password -o tsv)
  echo "   already exists -> new secret created (app id: $APP_ID)"
else
  SECRET="$DATABRICKS_SP_CLIENT_SECRET"
  echo "   already exists -> keeping the secret from .env (app id: $APP_ID)"
fi
set_env AZURE_TENANT_ID "$TENANT_ID"
set_env DATABRICKS_SP_CLIENT_ID "$APP_ID"
set_env DATABRICKS_SP_CLIENT_SECRET "'$SECRET'"

echo "2. Adding it to the Databricks workspace (workspace + SQL access, no admin)..."
EXISTS=$(databricks service-principals list -p "$P" -o json | python3 -c "import sys, json
app = sys.argv[1]
print(any(sp.get('applicationId') == app for sp in (json.load(sys.stdin) or [])))" "$APP_ID")
if [ "$EXISTS" = "True" ]; then
  echo "   already in the workspace -> skipped"
else
  databricks service-principals create -p "$P" --json "{
    \"applicationId\": \"$APP_ID\",
    \"displayName\": \"$SP_NAME\",
    \"active\": true,
    \"entitlements\": [ { \"value\": \"workspace-access\" }, { \"value\": \"databricks-sql-access\" } ]
  }" > /dev/null
  echo "   added"
fi

echo "   checking that you have the 'Use' role on it (needed to deploy jobs that run as it)..."
# This role lives at account level; granting it needs the account console or the UI below.
# https://learn.microsoft.com/azure/databricks/security/auth/access-control/service-principal-acl
CAN_USE=$(databricks service-principals list -p "$P" --filter "permission eq 'servicePrincipal/use'" -o json \
  | python3 -c "import sys, json
app = sys.argv[1]
print(any(sp.get('applicationId') == app for sp in (json.load(sys.stdin) or [])))" "$APP_ID")
if [ "$CAN_USE" = "True" ]; then
  echo "   ok"
else
  echo "   ACTION NEEDED (one-time, in the workspace UI):"
  echo "   Settings > Identity and access > Service principals > $SP_NAME > Permissions"
  echo "   > Grant access > your user > permission 'Use' > Save"
  echo "   Without it, 'databricks bundle deploy' fails with: must have 'servicePrincipal.user' role"
fi

echo "3. Permission to use the SQL warehouse and the cluster policy (CAN_USE)..."
ACL="{\"access_control_list\": [ { \"service_principal_name\": \"$APP_ID\", \"permission_level\": \"CAN_USE\" } ]}"
databricks warehouses update-permissions "$DATABRICKS_WAREHOUSE_ID" -p "$P" --json "$ACL" > /dev/null
databricks cluster-policies update-permissions "$DATABRICKS_CLUSTER_POLICY_ID" -p "$P" --json "$ACL" > /dev/null
echo "   done"

echo "4. Unity Catalog grants (infra/04_grant_service_principal.sql)..."
python3 scripts/run_sql.py infra/04_grant_service_principal.sql

echo "5. Testing the connection as the service principal..."
# Isolated from ~/.databrickscfg, so only the service principal's credentials are used
EMPTY_CFG=$(mktemp); trap 'rm -f "$EMPTY_CFG"' EXIT
WHO=$(DATABRICKS_CONFIG_FILE="$EMPTY_CFG" DATABRICKS_HOST="$DATABRICKS_WORKSPACE_URL" \
      ARM_CLIENT_ID="$APP_ID" ARM_CLIENT_SECRET="$SECRET" ARM_TENANT_ID="$TENANT_ID" \
      databricks current-user me -o json | python3 -c "import sys, json; print(json.load(sys.stdin)['displayName'])")
echo "   logged in as: $WHO"

echo
echo "Done. Service principal credentials saved to .env (secret valid for 1 year, never commit .env)."
