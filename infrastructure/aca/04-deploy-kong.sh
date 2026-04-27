#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

load_env "${1:-${ENV_FILE_DEFAULT}}"
if [[ -f "${SCRIPT_DIR}/aca.generated.env" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/aca.generated.env"
fi

require_cmd az

for name in SUBSCRIPTION_ID RESOURCE_GROUP ACA_ENV_NAME ACR_NAME IMAGE_TAG JWT_SECRET JWT_ISSUER; do
  require_env "${name}"
done

az_subscription_context

ACR_LOGIN_SERVER="${ACR_LOGIN_SERVER:-$(az acr show --resource-group "${RESOURCE_GROUP}" --name "${ACR_NAME}" --query loginServer -o tsv)}"
ACR_USERNAME="$(az acr credential show --resource-group "${RESOURCE_GROUP}" --name "${ACR_NAME}" --query username -o tsv)"
ACR_PASSWORD="$(az acr credential show --resource-group "${RESOURCE_GROUP}" --name "${ACR_NAME}" --query passwords[0].value -o tsv)"
APP_INSIGHTS_CONNECTION_STRING="${APP_INSIGHTS_CONNECTION_STRING:-}"
CORS_ALLOW_ORIGIN="${CORS_ALLOW_ORIGIN:-*}"

print_header "Deploying Kong Gateway (external ingress)"
az containerapp up \
  --name "kong-gateway" \
  --resource-group "${RESOURCE_GROUP}" \
  --environment "${ACA_ENV_NAME}" \
  --image "${ACR_LOGIN_SERVER}/agriwizard-kong:${IMAGE_TAG}" \
  --ingress external \
  --target-port 8000 \
  --registry-server "${ACR_LOGIN_SERVER}" \
  --registry-username "${ACR_USERNAME}" \
  --registry-password "${ACR_PASSWORD}" \
  --cpu 0.5 \
  --memory 1.0Gi \
  --min-replicas 1 \
  --max-replicas 2 \
  --env-vars \
    "KONG_DATABASE=off" \
    "KONG_PROXY_LISTEN=0.0.0.0:8000" \
    "KONG_ADMIN_LISTEN=127.0.0.1:8001" \
    "KONG_LOG_LEVEL=info" \
    "KONG_JWT_SHARED_SECRET=${JWT_SECRET}" \
    "KONG_JWT_ISSUER=${JWT_ISSUER}" \
    "CORS_ALLOW_ORIGIN=${CORS_ALLOW_ORIGIN}" \
    "IAM_UPSTREAM_HOST=iam-service" \
    "IAM_UPSTREAM_PORT=8081" \
    "HARDWARE_UPSTREAM_HOST=hardware-service" \
    "HARDWARE_UPSTREAM_PORT=8082" \
    "ANALYTICS_UPSTREAM_HOST=analytics-service" \
    "ANALYTICS_UPSTREAM_PORT=8083" \
    "WEATHER_UPSTREAM_HOST=weather-service" \
    "WEATHER_UPSTREAM_PORT=8084" \
    "NOTIFICATION_UPSTREAM_HOST=notification-service" \
    "NOTIFICATION_UPSTREAM_PORT=8085" \
    "APPLICATIONINSIGHTS_CONNECTION_STRING=${APP_INSIGHTS_CONNECTION_STRING}"

KONG_FQDN="$(az containerapp show --name kong-gateway --resource-group "${RESOURCE_GROUP}" --query properties.configuration.ingress.fqdn -o tsv)"

print_header "Kong deployed"
echo "Gateway URL: https://${KONG_FQDN}"
echo "Try: https://${KONG_FQDN}/auth/login"
