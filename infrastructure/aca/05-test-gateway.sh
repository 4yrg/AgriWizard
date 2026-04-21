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
EXPECTED_ISSUER="${JWT_ISSUER:-agriwizard-iam}"

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

TOKEN_ISSUER="$(python - <<'PY' "${TOKEN}"
import base64
import json
import sys

token = sys.argv[1]
parts = token.split(".")
if len(parts) != 3:
    print("")
    sys.exit(0)
payload = parts[1] + "=" * (-len(parts[1]) % 4)
try:
    data = json.loads(base64.urlsafe_b64decode(payload.encode("ascii")).decode("utf-8"))
except Exception:
    print("")
    sys.exit(0)
print(data.get("iss", ""))
PY
)"

if [[ -z "${TOKEN_ISSUER}" ]]; then
  echo "Could not decode token issuer from JWT payload"
  exit 1
fi

if [[ "${TOKEN_ISSUER}" != "${EXPECTED_ISSUER}" ]]; then
  echo "JWT issuer mismatch: token iss='${TOKEN_ISSUER}', expected='${EXPECTED_ISSUER}'"
  echo "Ensure IAM JWT_ISSUER and Kong KONG_JWT_ISSUER are aligned."
  exit 1
fi

echo "JWT acquired. Validating protected routes..."

WEATHER_RESPONSE="$(curl -sS -w '\n%{http_code}' "${KONG_URL}/weather/recommendations" \
  -H "Authorization: Bearer ${TOKEN}")"
WEATHER_CODE="$(echo "${WEATHER_RESPONSE}" | tail -n1)"
WEATHER_BODY="$(echo "${WEATHER_RESPONSE}" | sed '$d')"
if [[ "${WEATHER_CODE}" != "200" ]]; then
  echo "Weather route failed with status ${WEATHER_CODE}"
  echo "Response: ${WEATHER_BODY}"
  if echo "${WEATHER_BODY}" | grep -q "invalid_token"; then
    echo "Likely JWT secret/issuer mismatch between IAM and Kong."
  fi
  exit 1
fi

echo "Weather route OK"

ANALYTICS_RESPONSE="$(curl -sS -w '\n%{http_code}' "${KONG_URL}/analytics/decisions/summary" \
  -H "Authorization: Bearer ${TOKEN}")"
ANALYTICS_CODE="$(echo "${ANALYTICS_RESPONSE}" | tail -n1)"
ANALYTICS_BODY="$(echo "${ANALYTICS_RESPONSE}" | sed '$d')"
if [[ "${ANALYTICS_CODE}" != "200" ]]; then
  echo "Analytics route failed with status ${ANALYTICS_CODE}"
  echo "Response: ${ANALYTICS_BODY}"
  if echo "${ANALYTICS_BODY}" | grep -q "invalid_token"; then
    echo "Likely JWT secret/issuer mismatch between IAM and Kong."
  fi
  exit 1
fi

echo "Analytics route OK"

print_header "Public exposure checks"
for app in iam-service hardware-service analytics-service weather-service notification-service; do
  fqdn="$(az containerapp show --name "${app}" --resource-group "${RESOURCE_GROUP}" --query properties.configuration.ingress.fqdn -o tsv 2>/dev/null || true)"
  ingress="$(az containerapp show --name "${app}" --resource-group "${RESOURCE_GROUP}" --query properties.configuration.ingress.external -o tsv 2>/dev/null || true)"
  echo "${app}: external=${ingress} fqdn=${fqdn:-n/a}"
done

echo "Smoke tests passed"
