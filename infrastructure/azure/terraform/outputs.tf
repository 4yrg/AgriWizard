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

# =============================================================================
# Kong API Gateway
# =============================================================================

output "kong_api_url" {
  description = "Kong API Gateway URL"
  value       = "https://${azurerm_container_app.kong.latest_revision_fqdn}"
}

output "kong_admin_url" {
  description = "Kong Admin API URL"
  value       = "http://${azurerm_container_app.kong.latest_revision_fqdn}:8001"
}

# =============================================================================
# HiveMQ MQTT Broker
# =============================================================================

output "hivemq_mqtt_url" {
  description = "HiveMQ MQTT Broker URL"
  value       = "mqtt://${azurerm_container_app.hivemq.latest_revision_fqdn}:1883"
}

output "hivemq_websocket_url" {
  description = "HiveMQ WebSocket URL"
  value       = "ws://${azurerm_container_app.hivemq.latest_revision_fqdn}:8083"
}

# =============================================================================
# Backend Services
# =============================================================================

output "iam_app_fqdn" {
  description = "IAM Container App FQDN"
  value       = "${var.resource_group_name}-${var.environment}-iam.${azurerm_container_app_environment.aca.default_domain}"
}

output "hardware_app_fqdn" {
  description = "Hardware Container App FQDN"
  value       = "${var.resource_group_name}-${var.environment}-hardware.${azurerm_container_app_environment.aca.default_domain}"
}

output "analytics_app_fqdn" {
  description = "Analytics Container App FQDN"
  value       = "${var.resource_group_name}-${var.environment}-analytics.${azurerm_container_app_environment.aca.default_domain}"
}

output "weather_app_fqdn" {
  description = "Weather Container App FQDN"
  value       = "${var.resource_group_name}-${var.environment}-weather.${azurerm_container_app_environment.aca.default_domain}"
}

output "notification_app_fqdn" {
  description = "Notification Container App FQDN"
  value       = "${var.resource_group_name}-${var.environment}-notification.${azurerm_container_app_environment.aca.default_domain}"
}

output "frontend_app_fqdn" {
  description = "Frontend Container App FQDN"
  value       = azurerm_container_app.frontend.latest_revision_fqdn
}

# =============================================================================
# Service Bus
# =============================================================================

output "service_bus_namespace" {
  description = "Service Bus namespace"
  value       = azurerm_servicebus_namespace.main.name
}

output "service_bus_connection_string" {
  description = "Service Bus connection string"
  value       = azurerm_servicebus_namespace.main.default_primary_connection_string
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