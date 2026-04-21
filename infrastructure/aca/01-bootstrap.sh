#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

load_env "${1:-${ENV_FILE_DEFAULT}}"
require_cmd az

for name in SUBSCRIPTION_ID RESOURCE_GROUP LOCATION ACA_ENV_NAME ACR_NAME LOG_ANALYTICS_NAME APP_INSIGHTS_NAME; do
  require_env "${name}"
done

print_header "Selecting subscription"
az_subscription_context

print_header "Registering required providers"
az provider register --namespace Microsoft.App >/dev/null
az provider register --namespace Microsoft.OperationalInsights >/dev/null
az provider register --namespace Microsoft.Insights >/dev/null
az provider register --namespace Microsoft.ContainerRegistry >/dev/null

print_header "Creating resource group"
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --output table

print_header "Ensuring Log Analytics workspace"
if ! az monitor log-analytics workspace show --resource-group "${RESOURCE_GROUP}" --workspace-name "${LOG_ANALYTICS_NAME}" >/dev/null 2>&1; then
  az monitor log-analytics workspace create \
    --resource-group "${RESOURCE_GROUP}" \
    --workspace-name "${LOG_ANALYTICS_NAME}" \
    --location "${LOCATION}" \
    --output table
else
  echo "Log Analytics workspace already exists: ${LOG_ANALYTICS_NAME}"
fi

LAW_CUSTOMER_ID="$(az monitor log-analytics workspace show \
  --resource-group "${RESOURCE_GROUP}" \
  --workspace-name "${LOG_ANALYTICS_NAME}" \
  --query customerId -o tsv)"

LAW_SHARED_KEY="$(az monitor log-analytics workspace get-shared-keys \
  --resource-group "${RESOURCE_GROUP}" \
  --workspace-name "${LOG_ANALYTICS_NAME}" \
  --query primarySharedKey -o tsv)"

LAW_RESOURCE_ID="$(az monitor log-analytics workspace show \
  --resource-group "${RESOURCE_GROUP}" \
  --workspace-name "${LOG_ANALYTICS_NAME}" \
  --query id -o tsv)"

print_header "Ensuring Application Insights"
if ! az monitor app-insights component show --app "${APP_INSIGHTS_NAME}" --resource-group "${RESOURCE_GROUP}" >/dev/null 2>&1; then
  az monitor app-insights component create \
    --app "${APP_INSIGHTS_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --kind web \
    --workspace "${LAW_RESOURCE_ID}" \
    --application-type web \
    --output table
else
  echo "Application Insights already exists: ${APP_INSIGHTS_NAME}"
fi

APP_INSIGHTS_CONNECTION_STRING="$(az monitor app-insights component show \
  --app "${APP_INSIGHTS_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --query connectionString -o tsv)"

print_header "Ensuring Azure Container Registry"
if ! az acr show --resource-group "${RESOURCE_GROUP}" --name "${ACR_NAME}" >/dev/null 2>&1; then
  az acr create \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${ACR_NAME}" \
    --sku Basic \
    --admin-enabled true \
    --output table
else
  echo "ACR already exists: ${ACR_NAME}"
fi

ACR_LOGIN_SERVER="$(az acr show --resource-group "${RESOURCE_GROUP}" --name "${ACR_NAME}" --query loginServer -o tsv)"

print_header "Ensuring Container Apps Environment"
if ! az containerapp env show --name "${ACA_ENV_NAME}" --resource-group "${RESOURCE_GROUP}" >/dev/null 2>&1; then
  az containerapp env create \
    --name "${ACA_ENV_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --logs-workspace-id "${LAW_CUSTOMER_ID}" \
    --logs-workspace-key "${LAW_SHARED_KEY}" \
    --output table
else
  echo "Container Apps environment already exists: ${ACA_ENV_NAME}"
fi

print_header "Writing generated outputs"
cat > "${SCRIPT_DIR}/aca.generated.env" <<EOF
ACR_LOGIN_SERVER=${ACR_LOGIN_SERVER}
APP_INSIGHTS_CONNECTION_STRING=${APP_INSIGHTS_CONNECTION_STRING}
LOG_ANALYTICS_CUSTOMER_ID=${LAW_CUSTOMER_ID}
EOF

echo "Created ${SCRIPT_DIR}/aca.generated.env"
