#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

export ENV_FILE="${ENV_FILE:-${PROJECT_ROOT}/infrastructure/aca/aca.env}"

load_env() {
  if [[ ! -f "${ENV_FILE}" ]]; then
    echo "Missing env file: ${ENV_FILE}"
    echo "Copy ${PROJECT_ROOT}/infrastructure/aca/aca.env.example -> ${ENV_FILE} and fill required values."
    exit 1
  fi
  set -a
  source "${ENV_FILE}"
  set +a
}

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Required command not found: ${cmd}" >&2
    exit 1
  fi
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: ${name}" >&2
    exit 1
  fi
}

print_header() {
  printf '\n========================================\n'
  printf '== %s\n' "$1"
  printf '========================================\n'
}

az_subscription_context() {
  require_env SUBSCRIPTION_ID
  az account set --subscription "${SUBSCRIPTION_ID}"
}

register_providers() {
  print_header "Registering Azure providers"
  az provider register --namespace Microsoft.App --wait >/dev/null 2>&1 || true
  az provider register --namespace Microsoft.OperationalInsights --wait >/dev/null 2>&1 || true
  az provider register --namespace Microsoft.Insights --wait >/dev/null 2>&1 || true
  az provider register --namespace Microsoft.ContainerRegistry --wait >/dev/null 2>&1 || true
  echo "Providers registered"
}

create_resource_group() {
  print_header "Creating Resource Group"
  require_env RESOURCE_GROUP LOCATION
  
  if az group show --name "${RESOURCE_GROUP}" >/dev/null 2>&1; then
    echo "Resource group already exists: ${RESOURCE_GROUP}"
  else
    az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}" --output table
  fi
}

create_log_analytics() {
  print_header "Ensuring Log Analytics Workspace"
  require_env RESOURCE_GROUP LOG_ANALYTICS_NAME LOCATION
  
  if az monitor log-analytics workspace show \
    --resource-group "${RESOURCE_GROUP}" \
    --workspace-name "${LOG_ANALYTICS_NAME}" >/dev/null 2>&1; then
    echo "Log Analytics workspace already exists: ${LOG_ANALYTICS_NAME}"
  else
    az monitor log-analytics workspace create \
      --resource-group "${RESOURCE_GROUP}" \
      --workspace-name "${LOG_ANALYTICS_NAME}" \
      --location "${LOCATION}" \
      --output table
  fi
  
  LAW_CUSTOMER_ID="$(az monitor log-analytics workspace show \
    --resource-group "${RESOURCE_GROUP}" \
    --workspace-name "${LOG_ANALYTICS_NAME}" \
    --query customerId -o tsv)"
  
  LAW_SHARED_KEY="$(az monitor log-analytics workspace get-shared-keys \
    --resource-group "${RESOURCE_GROUP}" \
    --workspace-name "${LOG_ANALYTICS_NAME}" \
    --query primarySharedKey -o tsv)"
  
  export LAW_CUSTOMER_ID
  export LAW_SHARED_KEY
}

create_app_insights() {
  print_header "Ensuring Application Insights"
  require_env RESOURCE_GROUP APP_INSIGHTS_NAME LOCATION
  
  if az monitor app-insights component show \
    --app "${APP_INSIGHTS_NAME}" \
    --resource-group "${RESOURCE_GROUP}" >/dev/null 2>&1; then
    echo "Application Insights already exists: ${APP_INSIGHTS_NAME}"
  else
    local workspace_id
    workspace_id=$(az monitor log-analytics workspace show \
      --resource-group "${RESOURCE_GROUP}" \
      --workspace-name "${LOG_ANALYTICS_NAME}" \
      --query id -o tsv)
    
    az monitor app-insights component create \
      --app "${APP_INSIGHTS_NAME}" \
      --resource-group "${RESOURCE_GROUP}" \
      --location "${LOCATION}" \
      --kind web \
      --workspace "${workspace_id}" \
      --application-type web \
      --output table
  fi
}

create_acr() {
  print_header "Ensuring Azure Container Registry"
  require_env RESOURCE_GROUP ACR_NAME
  
  if az acr show --resource-group "${RESOURCE_GROUP}" --name "${ACR_NAME}" >/dev/null 2>&1; then
    echo "ACR already exists: ${ACR_NAME}"
    az acr update --resource-group "${RESOURCE_GROUP}" --name "${ACR_NAME}" --admin-enabled true --output table 2>/dev/null || true
  else
    az acr create \
      --resource-group "${RESOURCE_GROUP}" \
      --name "${ACR_NAME}" \
      --sku Basic \
      --admin-enabled true \
      --location "${LOCATION}" \
      --output table
  fi
  
  ACR_LOGIN_SERVER="$(az acr show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${ACR_NAME}" \
    --query loginServer -o tsv)"
  
  ACR_USERNAME="$(az acr credential show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${ACR_NAME}" \
    --query username -o tsv)"
  
  ACR_PASSWORD="$(az acr credential show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${ACR_NAME}" \
    --query passwords[0].value -o tsv)"
  
  export ACR_LOGIN_SERVER
  export ACR_USERNAME
  export ACR_PASSWORD
}

create_container_apps_env() {
  print_header "Ensuring Container Apps Environment"
  require_env RESOURCE_GROUP ACA_ENV_NAME LOCATION
  
  if az containerapp env show \
    --name "${ACA_ENV_NAME}" \
    --resource-group "${RESOURCE_GROUP}" >/dev/null 2>&1; then
    echo "Container Apps environment already exists: ${ACA_ENV_NAME}"
  else
    az containerapp env create \
      --name "${ACA_ENV_NAME}" \
      --resource-group "${RESOURCE_GROUP}" \
      --location "${LOCATION}" \
      --logs-workspace-id "${LAW_CUSTOMER_ID}" \
      --logs-workspace-key "${LAW_SHARED_KEY}" \
      --output table
  fi
}

deploy_container_app() {
  local app_name="$1"
  local image="$2"
  local port="$3"
  local env_vars="${4:-}"
  
  echo "Deploying ${app_name}..."
  
  local create_cmd="az containerapp create \
    --name ${app_name} \
    --resource-group ${RESOURCE_GROUP} \
    --environment ${ACA_ENV_NAME} \
    --image ${image} \
    --cpu 0.25 --memory 0.5Gi \
    --min-replicas 1 --max-replicas 1 \
    --ingress external --target-port ${port} \
    --output table"
  
  if az containerapp show --name "${app_name}" --resource-group "${RESOURCE_GROUP}" >/dev/null 2>&1; then
    echo "  Updating existing app: ${app_name}"
    az containerapp update \
      --name "${app_name}" \
      --resource-group "${RESOURCE_GROUP}" \
      --image "${image}" \
      --output table >/dev/null
  else
    echo "  Creating new app: ${app_name}"
    eval "${create_cmd}"
  fi
  
  if [[ -n "${env_vars}" ]]; then
    echo "  Setting environment variables..."
    IFS='|' read -ra ENVS <<< "${env_vars}"
    for env_pair in "${ENVS[@]}"; do
      local key="${env_pair%%=*}"
      local val="${env_pair#*=}"
      az containerapp secret set \
        --name "${app_name}" \
        --resource-group "${RESOURCE_GROUP}" \
        --secret-name "${key}" \
        --value "${val}" >/dev/null 2>&1 || true
    done
  fi
}

deploy_kong() {
  local app_name="kong"
  local image="kong:3.4"
  local port=8000
  
  echo "Deploying Kong API Gateway..."
  
  if az containerapp show \
    --name "${app_name}" \
    --resource-group "${RESOURCE_GROUP}" >/dev/null 2>&1; then
    echo "  Updating existing Kong..."
    az containerapp update \
      --name "${app_name}" \
      --resource-group "${RESOURCE_GROUP}" \
      --image "${image}" \
      --output table >/dev/null
  else
    echo "  Creating new Kong..."
    az containerapp create \
      --name "${app_name}" \
      --resource-group "${RESOURCE_GROUP}" \
      --environment "${ACA_ENV_NAME}" \
      --image "${image}" \
      --port "${port}" \
      --cpu 0.5 --memory 1Gi \
      --min-replicas 1 --max-replicas 1 \
      --ingress external --target-port "${port}" \
      --output table
  fi
}

get_default_env_vars() {
  local jwt_secret="${JWT_SECRET:-change-me-in-production-min-32-chars}"
  local db_host="${DB_HOST:-}"
  local db_user="${DB_USER:-agriwizard}"
  local db_password="${DB_PASSWORD:-}"
  local db_name="${DB_NAME:-agriwizard}"
  local postgres_port="${DB_PORT:-5432}"
  local db_sslmode="${DB_SSLMODE:-require}"
  
  local rabbitmq_host="agriwizard-rabbitmq"
  local rabbitmq_user="${RABBITMQ_USERNAME:-guest}"
  local rabbitmq_pass="${RABBITMQ_PASSWORD:-guest}"
  
  local env_vars=""
  
  if [[ -n "${db_host}" ]]; then
    env_vars="DB_HOST=${db_host}|DB_PORT=${postgres_port}|DB_USER=${db_user}|DB_PASSWORD=${db_password}|DB_NAME=${db_name}|DB_SSLMODE=${db_sslmode}|JWT_SECRET=${jwt_secret}"
  fi
  
  # Add RabbitMQ env vars
  env_vars="${env_vars}|RABBITMQ_HOST=${rabbitmq_host}|RABBITMQ_USERNAME=${rabbitmq_user}|RABBITMQ_PASSWORD=${rabbitmq_pass}|RABBITMQ_QUEUE=telemetry"
  
  echo "${env_vars}"
}

deploy_rabbitmq() {
  local app_name="agriwizard-rabbitmq"
  local image="rabbitmq:3.12-management"
  local port=5672
  
  echo "Deploying RabbitMQ..."
  
  if az containerapp show \
    --name "${app_name}" \
    --resource-group "${RESOURCE_GROUP}" >/dev/null 2>&1; then
    echo "  Updating existing RabbitMQ..."
    az containerapp update \
      --name "${app_name}" \
      --resource-group "${RESOURCE_GROUP}" \
      --image "${image}" \
      --output table >/dev/null
  else
    echo "  Creating new RabbitMQ..."
    az containerapp create \
      --name "${app_name}" \
      --resource-group "${RESOURCE_GROUP}" \
      --environment "${ACA_ENV_NAME}" \
      --image "${image}" \
      --port "${port}" \
      --ingress external \
      --cpu 0.5 --memory 1Gi \
      --min-replicas 1 --max-replicas 1 \
      --output table
  fi
  
  # Set RabbitMQ management plugin environment vars
  az containerapp secret set \
    --name "${app_name}" \
    --resource-group "${RESOURCE_GROUP}" \
    --secret-name "RABBITMQ_DEFAULT_USER" \
    --value "${RABBITMQ_USERNAME:-guest}" >/dev/null 2>&1 || true
  az containerapp secret set \
    --name "${app_name}" \
    --resource-group "${RESOURCE_GROUP}" \
    --secret-name "RABBITMQ_DEFAULT_PASS" \
    --value "${RABBITMQ_PASSWORD:-guest}" >/dev/null 2>&1 || true
}

main() {
  echo "========================================"
  echo "AgriWizard Azure Infrastructure Bootstrap"
  echo "========================================"
  echo ""
  echo "Configuration file: ${ENV_FILE}"
  echo "Resource Group: ${RESOURCE_GROUP:-<not set>}"
  echo ""
  
  if [[ ! -f "${ENV_FILE}" ]]; then
    echo "ERROR: Configuration file not found: ${ENV_FILE}"
    echo ""
    echo "Please create the configuration file by copying the example:"
    echo "  cp ${PROJECT_ROOT}/infrastructure/aca/aca.env.example ${ENV_FILE}"
    echo "  # Then edit ${ENV_FILE} with your values"
    exit 1
  fi
  
  load_env
  
  require_cmd az
  require_env SUBSCRIPTION_ID RESOURCE_GROUP LOCATION ACA_ENV_NAME ACR_NAME
  
  register_providers
  create_resource_group
  create_log_analytics
  create_app_insights
  create_acr
  create_container_apps_env
  
  print_header "Deploying Container Apps"
  
  local acr_image="${ACR_LOGIN_SERVER}/agriwizard-"
  local default_env_vars
  default_env_vars=$(get_default_env_vars)
  
  deploy_container_app "iam-service" "${acr_image}iam-service:latest" 8081 "${default_env_vars}"
  deploy_container_app "hardware-service" "${acr_image}hardware-service:latest" 8082 "${default_env_vars}"
  deploy_container_app "analytics-service" "${acr_image}analytics-service:latest" 8083 "${default_env_vars}"
  deploy_container_app "weather-service" "${acr_image}weather-service:latest" 8084 "${default_env_vars}"
  deploy_container_app "notification-service" "${acr_image}notification-service:latest" 8085 "${default_env_vars}"
  
  deploy_rabbitmq
  deploy_kong
  
  print_header "Bootstrap Complete"
  echo ""
  echo "Resources created:"
  echo "  - Resource Group: ${RESOURCE_GROUP}"
  echo "  - ACR: ${ACR_NAME} (${ACR_LOGIN_SERVER})"
  echo "  - Container Apps Environment: ${ACA_ENV_NAME}"
  echo "  - Log Analytics: ${LOG_ANALYTICS_NAME}"
  echo "  - App Insights: ${APP_INSIGHTS_NAME}"
  echo ""
  echo "Container Apps deployed:"
  echo "  - Kong Gateway: http://localhost:8000"
  echo "  - IAM Service"
  echo "  - Hardware Service"
  echo "  - Analytics Service"
  echo "  - Weather Service"
  echo "  - Notification Service"
  echo ""
  echo "Next steps:"
  echo "  1. Configure GitHub Secrets (see README.md)"
  echo "  2. Push to main branch to trigger CI/CD"
  echo ""
}

main "$@"
