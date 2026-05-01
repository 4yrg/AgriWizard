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

echo "🚀 Building and pushing image to ACR: ${ACR_NAME}..."
az acr build --registry "$ACR_NAME" --image "${IMAGE_NAME}:${TAG}" gateway/

echo "🔄 Updating Azure Container App: ${APP_NAME}"
# Following best practices: explicitly set registry and identity configuration
if [ -n "$IDENTITY_ID" ]; then
  az containerapp update \
    --name "$APP_NAME" \
    --resource-group "$RG" \
    --image "$FULL_IMAGE" \
    --user-assigned "$IDENTITY_ID" \
    --registry-identity "$IDENTITY_ID" \
    --registry-server "$ACR_LOGIN_SERVER"
else
  az containerapp update \
    --name "$APP_NAME" \
    --resource-group "$RG" \
    --image "$FULL_IMAGE" \
    --registry-server "$ACR_LOGIN_SERVER"
fi

echo "✅ Done. New image deployed: ${FULL_IMAGE}"
