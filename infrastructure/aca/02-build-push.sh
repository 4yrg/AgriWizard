#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

load_env "${1:-${ENV_FILE_DEFAULT}}"
require_cmd az

for name in SUBSCRIPTION_ID RESOURCE_GROUP ACR_NAME IMAGE_TAG; do
  require_env "${name}"
done

az_subscription_context

print_header "Building and pushing images to ACR"

SERVICES=(
  "agriwizard-iam-service|services/iam-service/Dockerfile"
  "agriwizard-hardware-service|services/hardware-service/Dockerfile"
  "agriwizard-analytics-service|services/analytics-service/Dockerfile"
  "agriwizard-weather-service|services/weather-service/Dockerfile"
  "agriwizard-notification-service|services/notification-service/Dockerfile"
  "agriwizard-kong|infrastructure/kong/Dockerfile"
)

for entry in "${SERVICES[@]}"; do
  IFS='|' read -r image_name dockerfile <<<"${entry}"
  print_header "Building ${image_name}:${IMAGE_TAG}"

  az acr build \
    --registry "${ACR_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --image "${image_name}:${IMAGE_TAG}" \
    --file "${dockerfile}" \
    "${PROJECT_ROOT}"

done

print_header "Build and push complete"
