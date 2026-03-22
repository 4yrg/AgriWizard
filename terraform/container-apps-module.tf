# =============================================================================
# AgriWizard - Container Apps Module Integration
# =============================================================================
# This file integrates the container-apps module with the main infrastructure.
# =============================================================================

# Deploy all AgriWizard microservices to Container Apps
module "container_apps" {
  source = "./modules/container-apps"

  # Resource configuration
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  container_apps_env_name    = azurerm_container_app_environment.main.name

  # Container Registry
  container_registry_server  = azurerm_container_registry.main.login_server
  container_registry_username = azurerm_container_registry.main.admin_username
  container_registry_password = azurerm_container_registry.main.admin_password

  # Image configuration
  image_tag = var.image_tag

  # Database configuration
  db_host     = azurerm_postgresql_flexible_server.main.fqdn
  db_port     = "5432"
  db_name     = azurerm_postgresql_flexible_server_database.agriwizard.name
  db_user     = var.postgresql_admin_username
  db_password = var.postgresql_admin_password

  # JWT Secret
  jwt_secret = var.jwt_secret

  # IoT Hub configuration
  iot_hub_name = azurerm_iothub.main.name

  # Environment
  environment = var.environment

  # Scaling configuration
  cpu_core     = var.cpu_core
  memory_size  = var.memory_size
  min_replicas = var.min_replicas
  max_replicas = var.max_replicas

  # Tags
  tags = local.common_tags

  depends_on = [
    azurerm_postgresql_flexible_server.main,
    azurerm_postgresql_flexible_server_database.agriwizard,
    azurerm_iothub.main,
    azurerm_container_registry.main,
    azurerm_container_app_environment.main
  ]
}

# =============================================================================
# API Management - Backend Services
# =============================================================================

# API Management - IAM Service Backend
resource "azurerm_api_management_backend" "iam_service" {
  name                = "iam-service-backend"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  protocol            = "http"
  url                 = "http://${module.container_apps.iam_service_url}:8081"
  title               = "IAM Service"
  description         = "Authentication and authorization service"
}

# API Management - Hardware Service Backend
resource "azurerm_api_management_backend" "hardware_service" {
  name                = "hardware-service-backend"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  protocol            = "http"
  url                 = "http://${module.container_apps.hardware_service_url}:8082"
  title               = "Hardware Service"
  description         = "IoT device and MQTT handling service"
}

# API Management - Analytics Service Backend
resource "azurerm_api_management_backend" "analytics_service" {
  name                = "analytics-service-backend"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  protocol            = "http"
  url                 = "http://${module.container_apps.analytics_service_url}:8083"
  title               = "Analytics Service"
  description         = "Rules, thresholds, and decision engine"
}

# API Management - Weather Service Backend
resource "azurerm_api_management_backend" "weather_service" {
  name                = "weather-service-backend"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  protocol            = "http"
  url                 = "http://${module.container_apps.weather_service_url}:8084"
  title               = "Weather Service"
  description         = "Weather data and irrigation recommendations"
}

# =============================================================================
# API Management - API Operations
# =============================================================================

# API Management - IAM Operations
resource "azurerm_api_management_api_operation" "iam_operations" {
  operation_id        = "iam-operations"
  api_name            = azurerm_api_management_api.agriwizard.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "IAM Operations"
  method              = "ANY"
  url_template        = "/iam/*"
}

# API Management - Hardware Operations
resource "azurerm_api_management_api_operation" "hardware_operations" {
  operation_id        = "hardware-operations"
  api_name            = azurerm_api_management_api.agriwizard.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "Hardware Operations"
  method              = "ANY"
  url_template        = "/hardware/*"
}

# API Management - Analytics Operations
resource "azurerm_api_management_api_operation" "analytics_operations" {
  operation_id        = "analytics-operations"
  api_name            = azurerm_api_management_api.agriwizard.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "Analytics Operations"
  method              = "ANY"
  url_template        = "/analytics/*"
}

# API Management - Weather Operations
resource "azurerm_api_management_api_operation" "weather_operations" {
  operation_id        = "weather-operations"
  api_name            = azurerm_api_management_api.agriwizard.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "Weather Operations"
  method              = "ANY"
  url_template        = "/weather/*"
}

# =============================================================================
# Key Vault Secrets
# =============================================================================

# Store database password in Key Vault
resource "azurerm_key_vault_secret" "db_password" {
  name         = "database-password"
  value        = var.postgresql_admin_password
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [
    azurerm_key_vault.main
  ]
}

# Store JWT secret in Key Vault
resource "azurerm_key_vault_secret" "jwt_secret" {
  name         = "jwt-secret"
  value        = var.jwt_secret
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [
    azurerm_key_vault.main
  ]
}

# Store IoT Hub connection string in Key Vault
resource "azurerm_key_vault_secret" "iot_hub_connection" {
  name         = "iot-hub-connection-string"
  value        = "HostName=${var.iot_hub_name}.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=<replace-with-actual-key>"
  key_vault_id = azurerm_key_vault.main.id
  sensitive    = true

  depends_on = [
    azurerm_key_vault.main
  ]
}
