#!/bin/bash
# 01_create_workspace.sh: creates the resource group, the Azure Databricks workspace (Premium) and a budget alert
# Usage (from the repo root): bash infra/01_create_workspace.sh
# Reads AZURE_* and DATABRICKS_WORKSPACE_NAME from .env, writes DATABRICKS_WORKSPACE_URL back to .env.
# Safe to re-run: existing resources are kept.
set -euo pipefail

# 0. Load .env
if [ ! -f .env ]; then
  echo "ERROR: .env not found. Run from the repo root (see .env.example)."
  exit 1
fi
set -a; source .env; set +a
: "${AZURE_SUBSCRIPTION_ID:?missing in .env}" "${AZURE_LOCATION:?missing in .env}"
: "${AZURE_RESOURCE_GROUP:?missing in .env}" "${DATABRICKS_WORKSPACE_NAME:?missing in .env}"
: "${AZURE_BUDGET_AMOUNT:?missing in .env}"

# Writes KEY=VALUE into .env (replaces the line if it exists)
set_env() {
  if grep -q "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else echo "$1=$2" >> .env; fi
}

echo "1. Logging in to Azure (browser or device code)..."
az account show > /dev/null 2>&1 || az login --use-device-code > /dev/null
az account set --subscription "$AZURE_SUBSCRIPTION_ID"
echo "   subscription: $(az account show --query name -o tsv)"

echo "2. Registering the Databricks provider + CLI extension (one-time)..."
az provider register --namespace Microsoft.Databricks --wait
az extension add --name databricks --upgrade --only-show-errors

echo "3. Creating resource group $AZURE_RESOURCE_GROUP in $AZURE_LOCATION..."
az group create \
  --name "$AZURE_RESOURCE_GROUP" \
  --location "$AZURE_LOCATION" \
  --tags project=clickstream-databricks-lakehouse \
  --output none

echo "4. Creating Databricks workspace $DATABRICKS_WORKSPACE_NAME (Premium, needed for Unity Catalog; ~5 min)..."
# --enable-no-public-ip false: cluster nodes get a public IP only while they run.
# The default (true, secure cluster connectivity) adds a NAT gateway to the managed resource group,
# which is billed per hour even when no cluster runs (~1 EUR/day). Inbound traffic stays blocked by the NSG.
if az databricks workspace show -g "$AZURE_RESOURCE_GROUP" -n "$DATABRICKS_WORKSPACE_NAME" > /dev/null 2>&1; then
  echo "   already exists -> skipped"
else
  az databricks workspace create \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --name "$DATABRICKS_WORKSPACE_NAME" \
    --location "$AZURE_LOCATION" \
    --sku premium \
    --enable-no-public-ip false \
    --managed-resource-group "mrg-$DATABRICKS_WORKSPACE_NAME" \
    --tags project=clickstream-databricks-lakehouse \
    --output none
fi

echo "   checking the managed resource group for a NAT gateway (billed even when idle)..."
if az resource list -g "mrg-$DATABRICKS_WORKSPACE_NAME" --resource-type Microsoft.Network/natGateways --query "[].name" -o tsv | grep -q .; then
  echo "   WARNING: NAT gateway found in mrg-$DATABRICKS_WORKSPACE_NAME (~1 EUR/day). Recreate the workspace with --enable-no-public-ip false."
else
  echo "   no NAT gateway -> no idle network cost"
fi

echo "5. Saving the workspace URL to .env..."
WORKSPACE_URL="https://$(az databricks workspace show -g "$AZURE_RESOURCE_GROUP" -n "$DATABRICKS_WORKSPACE_NAME" --query workspaceUrl -o tsv)"
set_env DATABRICKS_WORKSPACE_URL "$WORKSPACE_URL"
echo "   $WORKSPACE_URL"

echo "6. Creating a monthly budget alert (${AZURE_BUDGET_AMOUNT}, subscription scope)..."
# Subscription scope: Databricks compute runs in the managed resource group (mrg-*),
# so a budget on the project resource group alone would miss most of the cost.
# A budget only sends emails, it does not stop resources.
BUDGET_EMAIL=$(az account show --query user.name -o tsv)
START_DATE="$(date +%Y-%m)-01T00:00:00Z"
az rest --method put \
  --url "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/providers/Microsoft.Consumption/budgets/budget-clickstream?api-version=2023-05-01" \
  --body "{
    \"properties\": {
      \"category\": \"Cost\",
      \"amount\": $AZURE_BUDGET_AMOUNT,
      \"timeGrain\": \"Monthly\",
      \"timePeriod\": { \"startDate\": \"$START_DATE\" },
      \"notifications\": {
        \"actual_80_percent\": {
          \"enabled\": true, \"operator\": \"GreaterThanOrEqualTo\", \"threshold\": 80,
          \"thresholdType\": \"Actual\", \"contactEmails\": [\"$BUDGET_EMAIL\"]
        },
        \"forecast_100_percent\": {
          \"enabled\": true, \"operator\": \"GreaterThanOrEqualTo\", \"threshold\": 100,
          \"thresholdType\": \"Forecasted\", \"contactEmails\": [\"$BUDGET_EMAIL\"]
        }
      }
    }
  }" --output none
echo "   alerts go to $BUDGET_EMAIL (80% actual, 100% forecast)"

echo
echo "Done. Open the workspace: $WORKSPACE_URL"
