#!/usr/bin/env sh
set -eu

export KONG_JWT_SHARED_SECRET="${JWT_SECRET:-super-secret-jwt-key-change-in-production}"
export KONG_JWT_ISSUER="${JWT_ISSUER:-agriwizard-iam}"
export CORS_ALLOW_ORIGIN="${CORS_ALLOW_ORIGIN:-*}"

# Azure Container Apps - Public FQDN suffix
export ACA_FQDN_SUFFIX="${ACA_FQDN_SUFFIX:-purplesand-4413bcdd.centralindia.azurecontainerapps.io}"

# Internal container names (for reference) - NOT used for routing in Consumption mode
export IAM_UPSTREAM_HOST_INTERNAL="${IAM_UPSTREAM_HOST_INTERNAL:-iam-service}"
export HARDWARE_UPSTREAM_HOST_INTERNAL="${HARDWARE_UPSTREAM_HOST_INTERNAL:-hardware-service}"
export ANALYTICS_UPSTREAM_HOST_INTERNAL="${ANALYTICS_UPSTREAM_HOST_INTERNAL:-analytics-service}"
export WEATHER_UPSTREAM_HOST_INTERNAL="${WEATHER_UPSTREAM_HOST_INTERNAL:-weather-service}"
export NOTIFICATION_UPSTREAM_HOST_INTERNAL="${NOTIFICATION_UPSTREAM_HOST_INTERNAL:-notification-service}"

# Public URLs - Use these for Kong routing in Consumption mode (no internal DNS)
export IAM_UPSTREAM_PROTOCOL="${IAM_UPSTREAM_PROTOCOL:-https}"
export IAM_UPSTREAM_HOST="${IAM_UPSTREAM_HOST:-iam-service.${ACA_FQDN_SUFFIX}}"
export IAM_UPSTREAM_PORT="${IAM_UPSTREAM_PORT:-443}"
export HARDWARE_UPSTREAM_PROTOCOL="${HARDWARE_UPSTREAM_PROTOCOL:-https}"
export HARDWARE_UPSTREAM_HOST="${HARDWARE_UPSTREAM_HOST:-hardware-service.${ACA_FQDN_SUFFIX}}"
export HARDWARE_UPSTREAM_PORT="${HARDWARE_UPSTREAM_PORT:-443}"
export ANALYTICS_UPSTREAM_PROTOCOL="${ANALYTICS_UPSTREAM_PROTOCOL:-https}"
export ANALYTICS_UPSTREAM_HOST="${ANALYTICS_UPSTREAM_HOST:-analytics-service.${ACA_FQDN_SUFFIX}}"
export ANALYTICS_UPSTREAM_PORT="${ANALYTICS_UPSTREAM_PORT:-443}"
export WEATHER_UPSTREAM_PROTOCOL="${WEATHER_UPSTREAM_PROTOCOL:-https}"
export WEATHER_UPSTREAM_HOST="${WEATHER_UPSTREAM_HOST:-weather-service.${ACA_FQDN_SUFFIX}}"
export WEATHER_UPSTREAM_PORT="${WEATHER_UPSTREAM_PORT:-443}"
export NOTIFICATION_UPSTREAM_PROTOCOL="${NOTIFICATION_UPSTREAM_PROTOCOL:-https}"
export NOTIFICATION_UPSTREAM_HOST="${NOTIFICATION_UPSTREAM_HOST:-notification-service.${ACA_FQDN_SUFFIX}}"
export NOTIFICATION_UPSTREAM_PORT="${NOTIFICATION_UPSTREAM_PORT:-443}"

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
replace_var "IAM_UPSTREAM_PROTOCOL"
replace_var "IAM_UPSTREAM_HOST"
replace_var "IAM_UPSTREAM_PORT"
replace_var "HARDWARE_UPSTREAM_PROTOCOL"
replace_var "HARDWARE_UPSTREAM_HOST"
replace_var "HARDWARE_UPSTREAM_PORT"
replace_var "ANALYTICS_UPSTREAM_PROTOCOL"
replace_var "ANALYTICS_UPSTREAM_HOST"
replace_var "ANALYTICS_UPSTREAM_PORT"
replace_var "WEATHER_UPSTREAM_PROTOCOL"
replace_var "WEATHER_UPSTREAM_HOST"
replace_var "WEATHER_UPSTREAM_PORT"
replace_var "NOTIFICATION_UPSTREAM_PROTOCOL"
replace_var "NOTIFICATION_UPSTREAM_HOST"
replace_var "NOTIFICATION_UPSTREAM_PORT"

export KONG_DECLARATIVE_CONFIG="/etc/kong/kong.generated.yml"

exec /docker-entrypoint.sh kong docker-start
