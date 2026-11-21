#!/bin/bash
# setup_databricks_connection.sh: creates the Databricks CLI admin profile and tests the connection
# Usage (from the repo root): bash scripts/setup_databricks_connection.sh
# Prerequisite: infra/01_create_workspace.sh has run (DATABRICKS_WORKSPACE_URL is set in .env)
#
# - Auth type azure-cli: the CLI reuses your 'az login' session, so no token or password is stored
# - The profile is saved in ~/.databrickscfg (outside the repo)
# Safe to re-run: the profile is replaced.
set -euo pipefail

# 0. Load .env
if [ ! -f .env ]; then
  echo "ERROR: .env not found. Run from the repo root (see .env.example)."
  exit 1
fi
set -a; source .env; set +a
: "${DATABRICKS_WORKSPACE_URL:?missing in .env}" "${DATABRICKS_ADMIN_PROFILE:?missing in .env}"
if [[ "$DATABRICKS_WORKSPACE_URL" == *0000000000000000* ]]; then
  echo "ERROR: DATABRICKS_WORKSPACE_URL is still the placeholder. Run infra/01_create_workspace.sh first."
  exit 1
fi
CFG=~/.databrickscfg

echo "1. Checking the Azure login..."
az account show > /dev/null 2>&1 || az login --use-device-code > /dev/null
az account set --subscription "$AZURE_SUBSCRIPTION_ID"
echo "   subscription: $(az account show --query name -o tsv)"

echo "2. Writing profile [$DATABRICKS_ADMIN_PROFILE] to $CFG..."
touch "$CFG"
# remove an old version of this profile, keep all other profiles
awk -v s="[$DATABRICKS_ADMIN_PROFILE]" '$0==s{skip=1;next} /^\[/{skip=0} !skip' "$CFG" > "$CFG.tmp"
mv "$CFG.tmp" "$CFG"
cat >> "$CFG" << EOF

[$DATABRICKS_ADMIN_PROFILE]
host      = $DATABRICKS_WORKSPACE_URL
auth_type = azure-cli
EOF
chmod 600 "$CFG"

echo "3. Testing the connection..."
USER_NAME=$(databricks current-user me -p "$DATABRICKS_ADMIN_PROFILE" -o json | python3 -c "import sys, json; print(json.load(sys.stdin)['userName'])")
echo "   logged in as: $USER_NAME"

echo "4. Checking Unity Catalog (a metastore must be assigned to the workspace)..."
if METASTORE=$(databricks metastores current -p "$DATABRICKS_ADMIN_PROFILE" -o json 2>/dev/null); then
  echo "   metastore: $(echo "$METASTORE" | python3 -c "import sys, json; print(json.load(sys.stdin)['metastore_id'])")"
else
  echo "   WARNING: no Unity Catalog metastore assigned to this workspace."
  echo "   It is needed for Ch. 4 step 4. Check: Workspace > Catalog, or the account console."
fi

echo
echo "Done. Use the profile with: databricks <command> -p $DATABRICKS_ADMIN_PROFILE"
