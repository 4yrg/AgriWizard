# =============================================================================
# Outputs
# =============================================================================

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Resource group location"
  value       = azurerm_resource_group.main.location
}

# =============================================================================
# Database
# =============================================================================

output "postgresql_fqdn" {
  description = "PostgreSQL server FQDN"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

# =============================================================================
# Key Vault
# =============================================================================

output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}

# =============================================================================
# Container Registry
# =============================================================================

output "container_registry_name" {
  description = "Container Registry name"
  value       = azurerm_container_registry.acr.name
}

output "container_registry_login_server" {
  description = "Container Registry login server"
  value       = azurerm_container_registry.acr.login_server
}

# =============================================================================
# Container Apps Environment
# =============================================================================

output "container_apps_environment_name" {
  description = "Container Apps Environment name"
  value       = azurerm_container_app_environment.aca.name
}

output "iam_app_fqdn" {
  description = "IAM Container App FQDN"
  value       = azurerm_container_app.iam.fqdn
}

output "hardware_app_fqdn" {
  description = "Hardware Container App FQDN"
  value       = azurerm_container_app.hardware.fqdn
}

output "analytics_app_fqdn" {
  description = "Analytics Container App FQDN"
  value       = azurerm_container_app.analytics.fqdn
}

output "weather_app_fqdn" {
  description = "Weather Container App FQDN"
  value       = azurerm_container_app.weather.fqdn
}

output "notification_app_fqdn" {
  description = "Notification Container App FQDN"
  value       = azurerm_container_app.notification.fqdn
}

# =============================================================================
# Service Bus
# =============================================================================

output "service_bus_namespace" {
  description = "Service Bus namespace"
  value       = azurerm_service_bus_namespace.main.name
}

output "service_bus_connection_string" {
  description = "Service Bus connection string"
  value       = azurerm_service_bus_namespace.main.default_primary_connection_string
  sensitive  = true
}

# =============================================================================
# IoT Hub
# =============================================================================

output "iothub_name" {
  description = "IoT Hub name"
  value       = azurerm_iothub.main.name
}

output "iothub_connection_string" {
  description = "IoT Hub connection string"
  value       = azurerm_iothub.main.primary_connection_string
  sensitive  = true
}

# =============================================================================
# API Management
# =============================================================================

output "apim_name" {
  description = "API Management name"
  value       = azurerm_api_management.main.name
}

output "apim_gateway_url" {
  description = "API Management gateway URL"
  value       = azurerm_api_management.main.gateway_url
}

# =============================================================================
# Storage
# =============================================================================

output "storage_account_name" {
  description = "Storage account name"
  value       = azurerm_storage_account.main.name
}

output "storage_connection_string" {
  description = "Storage connection string"
  value       = azurerm_storage_account.main.primary_connection_string
  sensitive  = true
}

# =============================================================================
# Application Insights
# =============================================================================

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive  = true
}