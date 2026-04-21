#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

load_env "${1:-${ENV_FILE_DEFAULT}}"
if [[ -f "${SCRIPT_DIR}/aca.generated.env" ]]; then
  source "${SCRIPT_DIR}/aca.generated.env"
fi

require_cmd az

SERVICE_BUS_NAMESPACE="${SERVICE_BUS_NAMESPACE:-agriwizard-sb}"
SERVICE_BUS_SKU="${SERVICE_BUS_SKU:-Standard}"
SERVICE_BUS_TOPIC_TELEMETRY="${SERVICE_BUS_TOPIC_TELEMETRY:-telemetry}"
SERVICE_BUS_TOPIC_NOTIFICATIONS="${SERVICE_BUS_TOPIC_NOTIFICATIONS:-notifications}"

for name in SUBSCRIPTION_ID RESOURCE_GROUP LOCATION; do
  require_env "${name}"
done

az_subscription_context

print_header "Deploying Azure Service Bus"

echo "Namespace: ${SERVICE_BUS_NAMESPACE}"
echo "SKU: ${SERVICE_BUS_SKU}"
echo "Location: ${LOCATION}"

print_header "Creating Service Bus namespace"
if az servicebus namespace show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${SERVICE_BUS_NAMESPACE}" >/dev/null 2>&1; then
  echo "Service Bus namespace already exists: ${SERVICE_BUS_NAMESPACE}"
else
  az servicebus namespace create \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${SERVICE_BUS_NAMESPACE}" \
    --location "${LOCATION}" \
    --sku "${SERVICE_BUS_SKU}" \
    --output table
  
  echo "[INFO] Created Service Bus namespace: ${SERVICE_BUS_NAMESPACE}"
fi

SERVICE_BUS_CONNECTION=$(az servicebus namespace authorization-rule keys show \
  --resource-group "${RESOURCE_GROUP}" \
  --namespace-name "${SERVICE_BUS_NAMESPACE}" \
  --name RootManageSharedAccessKey \
  --query primaryConnectionString -o tsv)

echo ""
print_header "Creating topics"

for topic in "${SERVICE_BUS_TOPIC_TELEMETRY}" "${SERVICE_BUS_TOPIC_NOTIFICATIONS}"; do
  if az servicebus topic show \
    --resource-group "${RESOURCE_GROUP}" \
    --namespace-name "${SERVICE_BUS_NAMESPACE}" \
    --name "${topic}" >/dev/null 2>&1; then
    echo "Topic already exists: ${topic}"
  else
    az servicebus topic create \
      --resource-group "${RESOURCE_GROUP}" \
      --namespace-name "${SERVICE_BUS_NAMESPACE}" \
      --name "${topic}" \
      --output table
    echo "[INFO] Created topic: ${topic}"
  fi
done

echo ""
print_header "Creating subscriptions"

SUBSCRIPTIONS=(
  "${SERVICE_BUS_TOPIC_TELEMETRY}:analytics-service"
  "${SERVICE_BUS_TOPIC_NOTIFICATIONS}:notification-service"
)

for item in "${SUBSCRIPTIONS[@]}"; do
  topic="${item%%:*}"
  subscription="${item##*:}"
  
  if az servicebus subscription show \
    --resource-group "${RESOURCE_GROUP}" \
    --namespace-name "${SERVICE_BUS_NAMESPACE}" \
    --topic-name "${topic}" \
    --name "${subscription}" >/dev/null 2>&1; then
    echo "Subscription already exists: ${subscription} (topic: ${topic})"
  else
    az servicebus subscription create \
      --resource-group "${RESOURCE_GROUP}" \
      --namespace-name "${SERVICE_BUS_NAMESPACE}" \
      --topic-name "${topic}" \
      --name "${subscription}" \
      --output table
    echo "[INFO] Created subscription: ${subscription} (topic: ${topic})"
  fi
done

print_header "Service Bus deployment complete"

echo ""
echo "Connection string (for your environment):"
echo "${SERVICE_BUS_CONNECTION}"
echo ""

echo "Topics created:"
echo "  - ${SERVICE_BUS_TOPIC_TELEMETRY}"
echo "  - ${SERVICE_BUS_TOPIC_NOTIFICATIONS}"
echo ""
echo "Subscriptions created:"
echo "  - ${SERVICE_BUS_TOPIC_TELEMETRY}/${SERVICE_BUS_TOPIC_TELEMETRY} -> analytics-service"
echo "  - ${SERVICE_BUS_TOPIC_NOTIFICATIONS}/notifications -> notification-service"
echo ""

print_header "Updating aca.generated.env"

cat >> "${SCRIPT_DIR}/aca.generated.env" <<EOF
SERVICE_BUS_CONNECTION=${SERVICE_BUS_CONNECTION}
SERVICE_BUS_NAMESPACE=${SERVICE_BUS_NAMESPACE}
SERVICE_BUS_TOPIC=${SERVICE_BUS_TOPIC_TELEMETRY}
SERVICE_BUS_SUBSCRIPTION=analytics-service
EOF

echo "[INFO] Updated ${SCRIPT_DIR}/aca.generated.env"
print_header "Done"
