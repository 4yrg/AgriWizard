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

for name in SUBSCRIPTION_ID RESOURCE_GROUP ACA_ENV_NAME ACR_NAME IMAGE_TAG JWT_SECRET JWT_ISSUER POSTGRES_HOST POSTGRES_PORT POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD; do
  require_env "${name}"
done

az_subscription_context

ACR_LOGIN_SERVER="${ACR_LOGIN_SERVER:-$(az acr show --resource-group "${RESOURCE_GROUP}" --name "${ACR_NAME}" --query loginServer -o tsv)}"
ACR_USERNAME="$(az acr credential show --resource-group "${RESOURCE_GROUP}" --name "${ACR_NAME}" --query username -o tsv)"
ACR_PASSWORD="$(az acr credential show --resource-group "${RESOURCE_GROUP}" --name "${ACR_NAME}" --query passwords[0].value -o tsv)"
APP_INSIGHTS_CONNECTION_STRING="${APP_INSIGHTS_CONNECTION_STRING:-}"

SERVICE_BUS_CONNECTION="${SERVICE_BUS_CONNECTION:-}"
SERVICE_BUS_NAMESPACE="${SERVICE_BUS_NAMESPACE:-agriwizard-sb}"
SERVICE_BUS_TELEMETRY_TOPIC="${SERVICE_BUS_TOPIC:-telemetry}"
SERVICE_BUS_NOTIFICATIONS_TOPIC="${SERVICE_BUS_TOPIC:-notifications}"

SERVICE_BUS_TOPIC_TELEMETRY="${SERVICE_BUS_TOPIC_TELEMETRY:-telemetry}"
SERVICE_BUS_TOPIC_NOTIFICATIONS="${SERVICE_BUS_TOPIC_NOTIFICATIONS:-notifications}"

MQTT_BROKER="${MQTT_BROKER:-}"
MQTT_USERNAME="${MQTT_USERNAME:-}"
MQTT_PASSWORD="${MQTT_PASSWORD:-}"

NATS_URL="${NATS_URL:-nats://nats:4222}"
SMTP_HOST="${SMTP_HOST:-mailhog}"
SMTP_PORT="${SMTP_PORT:-1025}"
SMTP_FROM="${SMTP_FROM:-noreply@agriwizard.local}"
SMTP_USERNAME="${SMTP_USERNAME:-}"
SMTP_PASSWORD="${SMTP_PASSWORD:-}"
DB_SSLMODE="${DB_SSLMODE:-require}"

USE_MOCK="${USE_MOCK:-true}"
OWM_API_KEY="${OWM_API_KEY:-}"
OWM_BASE_URL="${OWM_BASE_URL:-https://api.openweathermap.org/data/2.5}"
LOCATION_LAT="${LOCATION_LAT:-6.9271}"
LOCATION_LON="${LOCATION_LON:-79.8612}"
LOCATION_CITY="${LOCATION_CITY:-Colombo}"

INGEST_CPU="${INGEST_CPU:-0.5}"
INGEST_MEMORY="${INGEST_MEMORY:-1.0Gi}"
LIGHT_CPU="${LIGHT_CPU:-0.25}"
LIGHT_MEMORY="${LIGHT_MEMORY:-0.5Gi}"

deploy_internal_app() {
  local app_name="$1"
  local image_name="$2"
  local target_port="$3"
  local min_replicas="$4"
  local max_replicas="$5"
  local cpu="$6"
  local memory="$7"
  shift 7
  local env_vars=("$@")

  print_header "Deploying ${app_name} (internal ingress)"
  az containerapp up \
    --name "${app_name}" \
    --resource-group "${RESOURCE_GROUP}" \
    --environment "${ACA_ENV_NAME}" \
    --image "${ACR_LOGIN_SERVER}/${image_name}:${IMAGE_TAG}" \
    --ingress internal \
    --target-port "${target_port}" \
    --registry-server "${ACR_LOGIN_SERVER}" \
    --registry-username "${ACR_USERNAME}" \
    --registry-password "${ACR_PASSWORD}" \
    --cpu "${cpu}" \
    --memory "${memory}" \
    --min-replicas "${min_replicas}" \
    --max-replicas "${max_replicas}" \
    --env-vars "${env_vars[@]}"
}

deploy_internal_app "iam-service" "agriwizard-iam-service" "8081" "1" "3" "${LIGHT_CPU}" "${LIGHT_MEMORY}" \
  "PORT=8081" \
  "DB_HOST=${POSTGRES_HOST}" \
  "DB_PORT=${POSTGRES_PORT}" \
  "DB_USER=${POSTGRES_USER}" \
  "DB_PASSWORD=${POSTGRES_PASSWORD}" \
  "DB_NAME=${POSTGRES_DB}" \
  "DB_SSLMODE=${DB_SSLMODE}" \
  "JWT_SECRET=${JWT_SECRET}" \
  "JWT_ISSUER=${JWT_ISSUER}" \
  "JWT_TTL_HOURS=24" \
  "GIN_MODE=release" \
  "APPLICATIONINSIGHTS_CONNECTION_STRING=${APP_INSIGHTS_CONNECTION_STRING}"

deploy_internal_app "hardware-service" "agriwizard-hardware-service" "8082" "1" "3" "${INGEST_CPU}" "${INGEST_MEMORY}" \
  "PORT=8082" \
  "DB_HOST=${POSTGRES_HOST}" \
  "DB_PORT=${POSTGRES_PORT}" \
  "DB_USER=${POSTGRES_USER}" \
  "DB_PASSWORD=${POSTGRES_PASSWORD}" \
  "DB_NAME=${POSTGRES_DB}" \
  "DB_SSLMODE=${DB_SSLMODE}" \
  "JWT_SECRET=${JWT_SECRET}" \
  "ANALYTICS_SERVICE_URL=http://analytics-service:8083" \
  "MQTT_BROKER=${MQTT_BROKER}" \
  "MQTT_USERNAME=${MQTT_USERNAME}" \
  "MQTT_PASSWORD=${MQTT_PASSWORD}" \
  "SERVICE_BUS_CONNECTION=${SERVICE_BUS_CONNECTION}" \
  "SERVICE_BUS_TOPIC=${SERVICE_BUS_TOPIC_TELEMETRY}" \
  "GIN_MODE=release" \
  "APPLICATIONINSIGHTS_CONNECTION_STRING=${APP_INSIGHTS_CONNECTION_STRING}"

deploy_internal_app "analytics-service" "agriwizard-analytics-service" "8083" "1" "3" "${INGEST_CPU}" "${INGEST_MEMORY}" \
  "PORT=8083" \
  "DB_HOST=${POSTGRES_HOST}" \
  "DB_PORT=${POSTGRES_PORT}" \
  "DB_USER=${POSTGRES_USER}" \
  "DB_PASSWORD=${POSTGRES_PASSWORD}" \
  "DB_NAME=${POSTGRES_DB}" \
  "DB_SSLMODE=${DB_SSLMODE}" \
  "JWT_SECRET=${JWT_SECRET}" \
  "HARDWARE_SERVICE_URL=http://hardware-service:8082" \
  "WEATHER_SERVICE_URL=http://weather-service:8084" \
  "SERVICE_BUS_CONNECTION=${SERVICE_BUS_CONNECTION}" \
  "SERVICE_BUS_NAMESPACE=${SERVICE_BUS_NAMESPACE}" \
  "SERVICE_BUS_TOPIC=${SERVICE_BUS_TOPIC_TELEMETRY}" \
  "SERVICE_BUS_SUBSCRIPTION=analytics-service" \
  "GIN_MODE=release" \
  "APPLICATIONINSIGHTS_CONNECTION_STRING=${APP_INSIGHTS_CONNECTION_STRING}"

deploy_internal_app "weather-service" "agriwizard-weather-service" "8084" "0" "2" "${LIGHT_CPU}" "${LIGHT_MEMORY}" \
  "PORT=8084" \
  "JWT_SECRET=${JWT_SECRET}" \
  "USE_MOCK=${USE_MOCK}" \
  "OWM_API_KEY=${OWM_API_KEY}" \
  "OWM_BASE_URL=${OWM_BASE_URL}" \
  "LOCATION_LAT=${LOCATION_LAT}" \
  "LOCATION_LON=${LOCATION_LON}" \
  "LOCATION_CITY=${LOCATION_CITY}" \
  "GIN_MODE=release" \
  "APPLICATIONINSIGHTS_CONNECTION_STRING=${APP_INSIGHTS_CONNECTION_STRING}"

deploy_internal_app "notification-service" "agriwizard-notification-service" "8085" "1" "3" "${LIGHT_CPU}" "${LIGHT_MEMORY}" \
  "PORT=8085" \
  "DB_HOST=${POSTGRES_HOST}" \
  "DB_PORT=${POSTGRES_PORT}" \
  "DB_USER=${POSTGRES_USER}" \
  "DB_PASSWORD=${POSTGRES_PASSWORD}" \
  "DB_NAME=${POSTGRES_DB}" \
  "DB_SSLMODE=${DB_SSLMODE}" \
  "NATS_URL=${NATS_URL}" \
  "SMTP_HOST=${SMTP_HOST}" \
  "SMTP_PORT=${SMTP_PORT}" \
  "SMTP_FROM=${SMTP_FROM}" \
  "SMTP_USERNAME=${SMTP_USERNAME}" \
  "SMTP_PASSWORD=${SMTP_PASSWORD}" \
  "SERVICE_BUS_CONNECTION=${SERVICE_BUS_CONNECTION}" \
  "SERVICE_BUS_NAMESPACE=${SERVICE_BUS_NAMESPACE}" \
  "SERVICE_BUS_TOPIC=${SERVICE_BUS_TOPIC_NOTIFICATIONS}" \
  "SERVICE_BUS_SUBSCRIPTION=notification-service" \
  "GIN_MODE=release" \
  "APPLICATIONINSIGHTS_CONNECTION_STRING=${APP_INSIGHTS_CONNECTION_STRING}"

print_header "Internal service deployment complete"
echo "Internal DNS examples:"
echo "  http://iam-service:8081"
echo "  http://hardware-service:8082"
echo "  http://analytics-service:8083"
echo "  http://weather-service:8084"
echo "  http://notification-service:8085"
