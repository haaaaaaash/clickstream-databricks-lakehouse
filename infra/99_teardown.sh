#!/bin/bash
# 99_teardown.sh: deletes everything this project created in Azure, so nothing keeps costing money
# Usage (from the repo root): bash infra/99_teardown.sh
# Deletes (cannot be undone):
#   1. Resource group rg-clickstream: the Databricks workspace, its managed resource group mrg-dbw-clickstream
#      (storage, network, all Delta tables, the volume with the CSVs, jobs, SQL warehouse, cluster policy)
#   2. Entra ID app registration + service principal sp-clickstream
#   3. Monthly budget budget-clickstream
#   4. Databricks CLI profile clickstream-admin in ~/.databrickscfg
# Not deleted: your Azure subscription, GitHub repo + secrets, local files.
# References:
#   az group delete:            https://learn.microsoft.com/cli/azure/group#az-group-delete
#   az ad app delete:           https://learn.microsoft.com/cli/azure/ad/app#az-ad-app-delete
#   az consumption budget delete: https://learn.microsoft.com/cli/azure/consumption/budget#az-consumption-budget-delete
set -euo pipefail

if [ ! -f .env ]; then echo "ERROR: .env not found. Run from the repo root."; exit 1; fi
set -a; source .env; set +a
: "${AZURE_SUBSCRIPTION_ID:?missing in .env}" "${AZURE_RESOURCE_GROUP:?missing in .env}" "${DATABRICKS_WORKSPACE_NAME:?missing in .env}"
MRG="mrg-$DATABRICKS_WORKSPACE_NAME"

az account show > /dev/null 2>&1 || az login --use-device-code > /dev/null
az account set --subscription "$AZURE_SUBSCRIPTION_ID"
echo "Subscription: $(az account show --query name -o tsv)"
echo "This deletes: resource group $AZURE_RESOURCE_GROUP (+ $MRG), service principal sp-clickstream, budget budget-clickstream."
read -r -p "Type 'delete' to continue: " ANSWER
[ "$ANSWER" = "delete" ] || { echo "Cancelled."; exit 0; }

echo "1. Deleting resource group $AZURE_RESOURCE_GROUP (workspace + $MRG; ~5-15 min)..."
if [ "$(az group exists --name "$AZURE_RESOURCE_GROUP")" = "true" ]; then
  az group delete --name "$AZURE_RESOURCE_GROUP" --yes
  echo "   deleted"
else
  echo "   not found -> skipped"
fi

echo "   checking the managed resource group $MRG (Databricks does not always remove it)..."
if [ "$(az group exists --name "$MRG")" = "true" ]; then
  # the workspace is gone, so its lock on the managed group is released and the group can be deleted directly
  az group delete --name "$MRG" --yes && echo "   $MRG deleted" \
    || echo "   $MRG still locked: wait 30 min, then run: az group delete --name $MRG --yes"
else
  echo "   already removed"
fi

echo "2. Deleting the service principal sp-clickstream (app registration)..."
APP_ID=$(az ad app list --display-name sp-clickstream --query "[0].appId" -o tsv)
if [ -n "$APP_ID" ]; then
  az ad app delete --id "$APP_ID"
  echo "   deleted"
else
  echo "   not found -> skipped"
fi

echo "3. Deleting the budget budget-clickstream..."
az consumption budget delete --budget-name budget-clickstream > /dev/null 2>&1 && echo "   deleted" || echo "   not found -> skipped"

echo "4. Removing the CLI profile clickstream-admin from ~/.databrickscfg..."
CFG="$HOME/.databrickscfg"
if [ -f "$CFG" ] && grep -q "^\[clickstream-admin\]" "$CFG"; then
  python3 - "$CFG" <<'PY'
import configparser, sys
p = sys.argv[1]; c = configparser.ConfigParser(); c.read(p)
c.remove_section("clickstream-admin")
with open(p, "w") as f: c.write(f)
PY
  echo "   removed"
else
  echo "   not found -> skipped"
fi

echo "5. Checking what is left..."
echo "   $AZURE_RESOURCE_GROUP exists: $(az group exists --name "$AZURE_RESOURCE_GROUP")"
echo "   $MRG exists: $(az group exists --name "$MRG")"
echo "   Resource groups still in the subscription:"
az group list --query "[].name" -o tsv | sed 's/^/     /'

echo
echo "Done. Costs stop now; the last charges can still appear in Cost analysis for 1-2 days."
