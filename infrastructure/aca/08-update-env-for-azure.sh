#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${SCRIPT_DIR}/common.sh"

ENV_FILE="${PROJECT_ROOT}/.env"
ACA_ENV_FILE="${SCRIPT_DIR}/aca.env"
ACA_ENV_BACKUP="${ACA_ENV_FILE}.backup.$(date +%Y%m%d%H%M%S)"

print_header "Migrating .env to Azure environment"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "[ERROR] Local .env file not found: ${ENV_FILE}"
  exit 1
fi

if [[ ! -f "${ACA_ENV_FILE}" ]]; then
  echo "[ERROR] Azure env file not found: ${ACA_ENV_FILE}"
  exit 1
fi

echo "Found local .env: ${ENV_FILE}"
echo "Found Azure env: ${ACA_ENV_FILE}"
echo ""

echo "Backing up aca.env to ${ACA_ENV_BACKUP}"
cp "${ACA_ENV_FILE}" "${ACA_ENV_BACKUP}"

source "${ENV_FILE}"

echo "Reading values from .env:"
echo "  MQTT_BROKER: ${MQTT_BROKER:-<not set>}"
echo "  MQTT_USERNAME: ${MQTT_USERNAME:-<not set>}"
echo "  DB_SSLMODE: will be set to 'require'"
echo ""

print_header "Updating aca.env"

update_env() {
  local key="$1"
  local value="$2"
  
  if grep -q "^${key}=" "${ACA_ENV_FILE}"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "${ACA_ENV_FILE}"
    echo "[UPDATED] ${key}=${value}"
  else
    echo "${key}=${value}" >> "${ACA_ENV_FILE}"
    echo "[ADDED] ${key}=${value}"
  fi
}

if [[ -n "${MQTT_BROKER:-}" ]]; then
  update_env "MQTT_BROKER" "${MQTT_BROKER}"
fi

if [[ -n "${MQTT_USERNAME:-}" ]]; then
  update_env "MQTT_USERNAME" "${MQTT_USERNAME}"
fi

if [[ -n "${MQTT_PASSWORD:-}" ]]; then
  update_env "MQTT_PASSWORD" "${MQTT_PASSWORD}"
fi

update_env "DB_SSLMODE" "require"

update_env "SERVICE_BUS_NAMESPACE" "agriwizard-sb"
update_env "SERVICE_BUS_TOPIC" "telemetry"
update_env "SERVICE_BUS_SUBSCRIPTION" "analytics-service"

print_header "Migration complete"

echo ""
echo "Summary of changes:"
echo "  - MQTT credentials migrated from .env"
echo "  - DB_SSLMODE set to 'require' (required for Azure PostgreSQL)"
echo "  - Service Bus configuration added (will be updated after running 07-deploy-servicebus.sh)"
echo ""
echo "Backup saved to: ${ACA_ENV_BACKUP}"
print_header "Done"
