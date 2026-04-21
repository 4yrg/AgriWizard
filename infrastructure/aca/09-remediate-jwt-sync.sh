#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

ENV_FILE="${1:-${ENV_FILE_DEFAULT}}"
load_env "${ENV_FILE}"

require_cmd az

for name in SUBSCRIPTION_ID RESOURCE_GROUP JWT_SECRET JWT_ISSUER; do
  require_env "${name}"
done

az_subscription_context

print_header "Applying IAM JWT settings"
az containerapp update \
  --name iam-service \
  --resource-group "${RESOURCE_GROUP}" \
  --set-env-vars \
    "JWT_SECRET=${JWT_SECRET}" \
    "JWT_ISSUER=${JWT_ISSUER}" >/dev/null

print_header "Applying Kong JWT settings"
az containerapp update \
  --name kong-gateway \
  --resource-group "${RESOURCE_GROUP}" \
  --set-env-vars \
    "KONG_JWT_SHARED_SECRET=${JWT_SECRET}" \
    "KONG_JWT_ISSUER=${JWT_ISSUER}" >/dev/null

print_header "JWT runtime remediation applied"
echo "IAM and Kong env values are now aligned for JWT validation."
echo "Running gateway smoke test..."

bash "${SCRIPT_DIR}/05-test-gateway.sh" "${ENV_FILE}"
