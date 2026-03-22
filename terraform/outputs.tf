
# =============================================================================
# AgriWizard - Azure Terraform Outputs
# =============================================================================

# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

output "resource_group_name" {
  description = "Name of the resource group"
  value       = data.azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = data.azurerm_resource_group.main.location
}

# -----------------------------------------------------------------------------
# Container Registry
# -----------------------------------------------------------------------------

output "acr_name" {
  description = "Azure Container Registry name"
  value       = azurerm_container_registry.main.name
}

output "acr_login_server" {
  description = "Azure Container Registry login server"
  value       = azurerm_container_registry.main.login_server
}

output "acr_admin_username" {
  description = "Azure Container Registry admin username"
  value       = azurerm_container_registry.main.admin_username
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Container Apps Environment
# -----------------------------------------------------------------------------

output "container_apps_environment_name" {
  description = "Container Apps Environment name"
  value       = azurerm_container_app_environment.main.name
}

output "container_apps_environment_id" {
  description = "Container Apps Environment ID"
  value       = azurerm_container_app_environment.main.id
}

# -----------------------------------------------------------------------------
# Container Apps - Service URLs
# -----------------------------------------------------------------------------

output "iam_service_fqdn" {
  description = "IAM Service fully qualified domain name"
  value       = module.container_apps.iam_service_url
}

output "hardware_service_fqdn" {
  description = "Hardware Service fully qualified domain name"
  value       = module.container_apps.hardware_service_url
}

output "analytics_service_fqdn" {
  description = "Analytics Service fully qualified domain name"
  value       = module.container_apps.analytics_service_url
}

output "weather_service_fqdn" {
  description = "Weather Service fully qualified domain name"
  value       = module.container_apps.weather_service_url
}

output "all_service_fqdns" {
  description = "All service FQDNs"
  value       = module.container_apps.all_service_urls
}

# -----------------------------------------------------------------------------
# API Management
# -----------------------------------------------------------------------------

output "apim_name" {
  description = "API Management service name"
  value       = azurerm_api_management.main.name
}

output "apim_gateway_url" {
  description = "API Management gateway URL"
  value       = azurerm_api_management.main.gateway_url
}

output "apim_portal_url" {
  description = "API Management developer portal URL"
  value       = azurerm_api_management.main.developer_portal_url
}

output "api_management_endpoint" {
  description = "Base API Management endpoint"
  value       = azurerm_api_management.main.gateway_url
}

# -----------------------------------------------------------------------------
# Database
# -----------------------------------------------------------------------------

output "postgresql_server_name" {
  description = "PostgreSQL server name"
  value       = azurerm_postgresql_flexible_server.main.name
}

output "postgresql_fqdn" {
  description = "PostgreSQL server fully qualified domain name"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "postgresql_database_name" {
  description = "PostgreSQL database name"
  value       = azurerm_postgresql_flexible_server_database.agriwizard.name
}

output "postgresql_connection_string" {
  description = "PostgreSQL connection string"
  value       = "host=${azurerm_postgresql_flexible_server.main.fqdn} port=5432 database=agriwizard user=${var.postgresql_admin_username} password=${var.postgresql_admin_password} sslmode=require"
  sensitive   = true
}

# -----------------------------------------------------------------------------
# IoT Hub
# -----------------------------------------------------------------------------

output "iot_hub_name" {
  description = "IoT Hub name"
  value       = azurerm_iothub.main.name
}

output "iot_hub_hostname" {
  description = "IoT Hub hostname for device connections"
  value       = "${azurerm_iothub.main.name}.azure-devices.net"
}

output "iot_hub_event_hub_endpoint" {
  description = "IoT Hub Event Hub-compatible endpoint"
  value       = "https://${azurerm_iothub.main.name}.azure-devices.net/events"
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Key Vault
# -----------------------------------------------------------------------------

output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}

output "key_vault_id" {
  description = "Key Vault resource ID"
  value       = azurerm_key_vault.main.id
}

# -----------------------------------------------------------------------------
# Monitoring
# -----------------------------------------------------------------------------

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Log Analytics Workspace name"
  value       = azurerm_log_analytics_workspace.main.name
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Application Insights connection string"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Managed Identity
# -----------------------------------------------------------------------------

output "container_apps_identity_principal_id" {
  description = "Container Apps Managed Identity principal ID"
  value       = azurerm_user_assigned_identity.container_apps.principal_id
}

output "container_apps_identity_client_id" {
  description = "Container Apps Managed Identity client ID"
  value       = azurerm_user_assigned_identity.container_apps.client_id
}

# -----------------------------------------------------------------------------
# Deployment Summary
# -----------------------------------------------------------------------------

output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    resource_group = data.azurerm_resource_group.main.name
    location       = data.azurerm_resource_group.main.location
    environment    = var.environment

    services = {
      iam       = module.container_apps.iam_service_url
      hardware  = module.container_apps.hardware_service_url
      analytics = module.container_apps.analytics_service_url
      weather   = module.container_apps.weather_service_url
    }

    api_gateway = azurerm_api_management.main.gateway_url
    database    = azurerm_postgresql_flexible_server.main.fqdn
    iot_hub     = "${azurerm_iothub.main.name}.azure-devices.net"
    key_vault   = azurerm_key_vault.main.vault_uri
  }
}
