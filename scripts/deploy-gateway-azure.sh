#!/usr/bin/env bash
set -euo pipefail

# deploy-gateway-azure.sh
# Build, push gateway nginx image to ACR using 'az acr build' and update the Azure Container App.
# Usage:
#   ACR_NAME=<myacr> RG=<resource-group> APP_NAME=<containerapp-name> ./scripts/deploy-gateway-azure.sh [tag]

IMAGE_NAME=agriwizard-gateway
TAG=${1:-latest}
RG=${RG:-agriwizard-prod-rg}
APP_NAME=${APP_NAME:-agriwizard-prod-gateway}

# Determine ACR_NAME if not provided
if [ -z "${ACR_NAME:-}" ]; then
  echo "🔍 Querying ACR name in resource group $RG..."
  ACR_NAME=$(az acr list --resource-group "$RG" --query "[0].name" -o tsv)
fi

if [ -z "$ACR_NAME" ]; then
  echo "❌ ERROR: ACR_NAME must be set or available in the resource group."
  exit 1
fi

ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"

echo "🚀 Building and pushing image to ACR: ${ACR_NAME} (using az acr build)..."
az acr build --registry "$ACR_NAME" --image "${IMAGE_NAME}:${TAG}" gateway/

FULL_IMAGE="${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${TAG}"

echo "🔄 Updating Azure Container App: ${APP_NAME} in RG ${RG} to image ${FULL_IMAGE}"
az containerapp update --name "$APP_NAME" --resource-group "$RG" --image "$FULL_IMAGE"

echo "✅ Done. New image deployed: ${FULL_IMAGE}"
