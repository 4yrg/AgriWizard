#!/usr/bin/env sh
set -eu

export KONG_JWT_SHARED_SECRET="${KONG_JWT_SHARED_SECRET:-super-secret-jwt-key-change-in-production}"
export KONG_JWT_ISSUER="${KONG_JWT_ISSUER:-${JWT_ISSUER:-agriwizard-iam}}"
export CORS_ALLOW_ORIGIN="${CORS_ALLOW_ORIGIN:-*}"

# Azure Container Apps - Use INTERNAL HTTP for same-environment services
# Internal DNS resolution works within the same Container Apps environment
export IAM_UPSTREAM_HOST="${IAM_UPSTREAM_HOST:-iam-service}"
export IAM_UPSTREAM_PORT="${IAM_UPSTREAM_PORT:-8081}"
export HARDWARE_UPSTREAM_HOST="${HARDWARE_UPSTREAM_HOST:-hardware-service}"
export HARDWARE_UPSTREAM_PORT="${HARDWARE_UPSTREAM_PORT:-8082}"
export ANALYTICS_UPSTREAM_HOST="${ANALYTICS_UPSTREAM_HOST:-analytics-service}"
export ANALYTICS_UPSTREAM_PORT="${ANALYTICS_UPSTREAM_PORT:-8083}"
export WEATHER_UPSTREAM_HOST="${WEATHER_UPSTREAM_HOST:-weather-service}"
export WEATHER_UPSTREAM_PORT="${WEATHER_UPSTREAM_PORT:-8084}"
export NOTIFICATION_UPSTREAM_HOST="${NOTIFICATION_UPSTREAM_HOST:-notification-service}"
export NOTIFICATION_UPSTREAM_PORT="${NOTIFICATION_UPSTREAM_PORT:-8085}"

cp /etc/kong/kong.template.yml /etc/kong/kong.generated.yml

replace_var() {
  var_name="$1"
  var_value="$(printenv "$var_name")"
  token="$(printf '${%s}' "$var_name")"
  escaped_value="$(printf '%s' "$var_value" | sed -e 's/[\/&]/\\&/g')"
  sed -i "s|$token|$escaped_value|g" /etc/kong/kong.generated.yml
}

replace_var "KONG_JWT_SHARED_SECRET"
replace_var "KONG_JWT_ISSUER"
replace_var "CORS_ALLOW_ORIGIN"
replace_var "IAM_UPSTREAM_HOST"
replace_var "IAM_UPSTREAM_PORT"
replace_var "HARDWARE_UPSTREAM_HOST"
replace_var "HARDWARE_UPSTREAM_PORT"
replace_var "ANALYTICS_UPSTREAM_HOST"
replace_var "ANALYTICS_UPSTREAM_PORT"
replace_var "WEATHER_UPSTREAM_HOST"
replace_var "WEATHER_UPSTREAM_PORT"
replace_var "NOTIFICATION_UPSTREAM_HOST"
replace_var "NOTIFICATION_UPSTREAM_PORT"

export KONG_DECLARATIVE_CONFIG="/etc/kong/kong.generated.yml"

exec /docker-entrypoint.sh kong docker-start
