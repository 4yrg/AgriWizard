#!/usr/bin/env bash
set -euo pipefail

# deploy-gateway-azure.sh
# Build, push gateway nginx image to ACR and update the Azure Container App.
# Usage:
#   ACR_LOGIN_SERVER=<myacr>.azurecr.io RG=<resource-group> APP_NAME=<containerapp-name> ./scripts/deploy-gateway-azure.sh [tag]

IMAGE_NAME=agriwizard-gateway
TAG=${1:-latest}
ACR_LOGIN_SERVER=${ACR_LOGIN_SERVER:-}
RG=${RG:-agriwizard-prod-rg}
APP_NAME=${APP_NAME:-agriwizard-gateway}

if [ -z "$ACR_LOGIN_SERVER" ]; then
  echo "ACR_LOGIN_SERVER must be set (e.g. myacr.azurecr.io)"
  exit 1
fi

echo "Building Docker image..."
docker build -t ${IMAGE_NAME}:${TAG} -f gateway/Dockerfile gateway

FULL_IMAGE=${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${TAG}

echo "Tagging image: ${FULL_IMAGE}"
docker tag ${IMAGE_NAME}:${TAG} ${FULL_IMAGE}

echo "Logging in to ACR..."
ACR_NAME=${ACR_LOGIN_SERVER%%.azurecr.io}
az acr login --name "$ACR_NAME"

echo "Pushing image to ACR: ${FULL_IMAGE}"
docker push ${FULL_IMAGE}

echo "Updating Azure Container App: ${APP_NAME} in RG ${RG} to image ${FULL_IMAGE}"
az containerapp update --name "$APP_NAME" --resource-group "$RG" --image "$FULL_IMAGE"

echo "Done. New image deployed: ${FULL_IMAGE}"
