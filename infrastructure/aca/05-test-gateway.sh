#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "${SCRIPT_DIR}/common.sh"

load_env "${1:-${ENV_FILE_DEFAULT}}"
require_cmd az
require_cmd curl

for name in SUBSCRIPTION_ID RESOURCE_GROUP; do
  require_env "${name}"
done

az_subscription_context

KONG_FQDN="$(az containerapp show --name kong-gateway --resource-group "${RESOURCE_GROUP}" --query properties.configuration.ingress.fqdn -o tsv)"
KONG_URL="https://${KONG_FQDN}"

print_header "Gateway smoke test"
echo "Gateway: ${KONG_URL}"

LOGIN_PAYLOAD='{"email":"admin@agriwizard.local","password":"admin123"}'
LOGIN_RESPONSE="$(curl -sS -X POST "${KONG_URL}/auth/login" -H "Content-Type: application/json" -d "${LOGIN_PAYLOAD}")"

TOKEN=""
if command -v jq >/dev/null 2>&1; then
  TOKEN="$(echo "${LOGIN_RESPONSE}" | jq -r '.token // empty')"
else
  TOKEN="$(echo "${LOGIN_RESPONSE}" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')"
fi

if [[ -z "${TOKEN}" ]]; then
  echo "Could not obtain JWT token from /auth/login"
  echo "Response: ${LOGIN_RESPONSE}"
  exit 1
fi

echo "JWT acquired. Validating protected routes..."

curl -sS -f "${KONG_URL}/weather/recommendations" \
  -H "Authorization: Bearer ${TOKEN}" >/dev/null

echo "Weather route OK"

curl -sS -f "${KONG_URL}/analytics/decisions/summary" \
  -H "Authorization: Bearer ${TOKEN}" >/dev/null

echo "Analytics route OK"

print_header "Public exposure checks"
for app in iam-service hardware-service analytics-service weather-service notification-service; do
  fqdn="$(az containerapp show --name "${app}" --resource-group "${RESOURCE_GROUP}" --query properties.configuration.ingress.fqdn -o tsv 2>/dev/null || true)"
  ingress="$(az containerapp show --name "${app}" --resource-group "${RESOURCE_GROUP}" --query properties.configuration.ingress.external -o tsv 2>/dev/null || true)"
  echo "${app}: external=${ingress} fqdn=${fqdn:-n/a}"
done

echo "Smoke tests passed"
