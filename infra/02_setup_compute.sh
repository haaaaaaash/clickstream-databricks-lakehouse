#!/bin/bash
# 02_setup_compute.sh: creates the SQL warehouse (for dbt) and a cluster policy (for the PySpark job)
# Usage (from the repo root): bash infra/02_setup_compute.sh
# Prerequisite: scripts/setup_databricks_connection.sh has run (admin profile works)
#
# Settings live in JSON files (single source of truth):
#   infra/compute/sql_warehouse.json   warehouse settings (name, size, auto-stop, serverless)
#   infra/compute/cluster_policy.json  policy definition (runtime, node type, auto-terminate, ...)
# Writes DATABRICKS_HTTP_PATH, DATABRICKS_WAREHOUSE_ID and DATABRICKS_CLUSTER_POLICY_ID to .env.
# Safe to re-run: existing warehouse/policy are updated, not duplicated.
set -euo pipefail

# 0. Load .env
if [ ! -f .env ]; then
  echo "ERROR: .env not found. Run from the repo root (see .env.example)."
  exit 1
fi
set -a; source .env; set +a
: "${DATABRICKS_ADMIN_PROFILE:?missing in .env}"
P="$DATABRICKS_ADMIN_PROFILE"
WAREHOUSE_JSON="infra/compute/sql_warehouse.json"
POLICY_JSON="infra/compute/cluster_policy.json"
POLICY_NAME="clickstream-job-policy"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

set_env() {
  if grep -q "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else echo "$1=$2" >> .env; fi
}
# Returns the id of the item with a given name from a JSON list on stdin
find_id() {
  python3 -c "import sys, json
name, key = sys.argv[1], sys.argv[2]
items = json.load(sys.stdin) or []
print(next((i[key] for i in items if i.get('name') == name), ''))" "$1" "$2"
}

WAREHOUSE_NAME=$(python3 -c "import sys, json; print(json.load(open(sys.argv[1]))['name'])" "$WAREHOUSE_JSON")

echo "1. SQL warehouse $WAREHOUSE_NAME (settings: $WAREHOUSE_JSON)..."
WAREHOUSE_ID=$(databricks warehouses list -p "$P" -o json | find_id "$WAREHOUSE_NAME" id)
if [ -n "$WAREHOUSE_ID" ]; then
  echo "   already exists -> updating settings"
  databricks warehouses edit "$WAREHOUSE_ID" -p "$P" --json @"$WAREHOUSE_JSON" --no-wait > /dev/null
else
  WAREHOUSE_ID=$(databricks warehouses create -p "$P" --json @"$WAREHOUSE_JSON" --no-wait -o json \
    | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
fi
set_env DATABRICKS_WAREHOUSE_ID "$WAREHOUSE_ID"
set_env DATABRICKS_HTTP_PATH "/sql/1.0/warehouses/$WAREHOUSE_ID"
echo "   id: $WAREHOUSE_ID"

echo "2. Cluster policy $POLICY_NAME (definition: $POLICY_JSON)..."
# The API expects the definition as a JSON string inside the request body
POLICY_ID=$(databricks cluster-policies list -p "$P" -o json | find_id "$POLICY_NAME" policy_id)
python3 -c "import sys, json
body = {'name': sys.argv[2], 'definition': json.dumps(json.load(open(sys.argv[1])))}
if sys.argv[3]:
    body['policy_id'] = sys.argv[3]
print(json.dumps(body))" "$POLICY_JSON" "$POLICY_NAME" "$POLICY_ID" > "$TMP/policy.json"
if [ -n "$POLICY_ID" ]; then
  echo "   already exists -> updating definition"
  databricks cluster-policies edit -p "$P" --json @"$TMP/policy.json"
else
  POLICY_ID=$(databricks cluster-policies create -p "$P" --json @"$TMP/policy.json" -o json \
    | python3 -c "import sys, json; print(json.load(sys.stdin)['policy_id'])")
fi
set_env DATABRICKS_CLUSTER_POLICY_ID "$POLICY_ID"
echo "   id: $POLICY_ID"

echo "3. Stopping the warehouse (it starts on creation; dbt will start it again when needed)..."
databricks warehouses stop "$WAREHOUSE_ID" -p "$P" --no-wait > /dev/null || true

echo
echo "Done. Compute ids saved to .env:"
grep -E "^DATABRICKS_(HTTP_PATH|WAREHOUSE_ID|CLUSTER_POLICY_ID)=" .env