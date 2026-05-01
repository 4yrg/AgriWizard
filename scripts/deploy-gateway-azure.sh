#!/usr/bin/env bash
set -euo pipefail

# deploy-gateway-azure.sh
# Build, push gateway nginx image to ACR and update the Azure Container App.
# Usage:
#   RG=<resource-group> APP_NAME=<containerapp-name> ./scripts/deploy-gateway-azure.sh [tag]

IMAGE_NAME=agriwizard-gateway
TAG=${1:-latest}
RG=${RG:-agriwizard-prod-rg}
APP_NAME=${APP_NAME:-agriwizard-prod-gateway}
FQDN_SUFFIX=${FQDN_SUFFIX:-yellowocean-38e04fed.centralindia.azurecontainerapps.io}

echo "🔍 Querying infrastructure details..."
ACR_NAME=$(az acr list --resource-group "$RG" --query "[0].name" -o tsv)
IDENTITY_ID=$(az identity list --resource-group "$RG" --query "[0].id" -o tsv)

if [ -z "$ACR_NAME" ]; then
  echo "❌ ERROR: Could not determine ACR name in resource group $RG"
  exit 1
fi

if [ -z "$IDENTITY_ID" ]; then
  echo "⚠️ WARNING: Could not determine Managed Identity ID. Deployment might fail if ACR access is not configured."
fi

ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"
FULL_IMAGE="${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${TAG}"

if command -v podman >/dev/null 2>&1; then
  CONTAINER_TOOL=podman
elif command -v docker >/dev/null 2>&1; then
  CONTAINER_TOOL=docker
else
  echo "❌ ERROR: Neither podman nor docker is available for building the gateway image"
  exit 1
fi

echo "🚀 Authenticating to ACR for ${CONTAINER_TOOL}..."
ACR_TOKEN=$(az acr login -n "$ACR_NAME" --expose-token --query accessToken -o tsv)
"$CONTAINER_TOOL" login "$ACR_LOGIN_SERVER" -u 00000000-0000-0000-0000-000000000000 -p "$ACR_TOKEN"

echo "🏗️ Building gateway image locally with ${CONTAINER_TOOL}..."
"$CONTAINER_TOOL" build -t "$FULL_IMAGE" gateway/

echo "📤 Pushing image to ACR: ${FULL_IMAGE}"
"$CONTAINER_TOOL" push "$FULL_IMAGE"

echo "🔄 Updating Azure Container App: ${APP_NAME}"
# Following best practices: explicitly set registry and identity configuration
if [ -n "$IDENTITY_ID" ]; then
  az containerapp update \
    --name "$APP_NAME" \
    --resource-group "$RG" \
    --image "$FULL_IMAGE" \
    --set-env-vars \
      IAM_SERVICE_HOST="iam-prod.${FQDN_SUFFIX}" \
      HARDWARE_SERVICE_HOST="hardware-prod.${FQDN_SUFFIX}" \
      ANALYTICS_SERVICE_HOST="analytics-prod.${FQDN_SUFFIX}" \
      WEATHER_SERVICE_HOST="weather-prod.${FQDN_SUFFIX}" \
      NOTIFICATION_SERVICE_HOST="notification-prod.${FQDN_SUFFIX}"
else
  az containerapp update \
    --name "$APP_NAME" \
    --resource-group "$RG" \
    --image "$FULL_IMAGE" \
    --set-env-vars \
      IAM_SERVICE_HOST="iam-prod.${FQDN_SUFFIX}" \
      HARDWARE_SERVICE_HOST="hardware-prod.${FQDN_SUFFIX}" \
      ANALYTICS_SERVICE_HOST="analytics-prod.${FQDN_SUFFIX}" \
      WEATHER_SERVICE_HOST="weather-prod.${FQDN_SUFFIX}" \
      NOTIFICATION_SERVICE_HOST="notification-prod.${FQDN_SUFFIX}"
fi

echo "✅ Done. New image deployed: ${FULL_IMAGE}"
