# Azure Key Vault

resource "azurerm_key_vault" "main" {
  name                = "${var.resource_group_name}-${var.environment}-kv"
  resource_group_name = azurerm_resource_group.main.location != "usgov" ? azurerm_resource_group.main.name : null
  location           = azurerm_resource_group.main.location
  tenant_id          = data.azurerm_client_config.current.tenant_id
  sku_name           = "standard"
  soft_delete_retention_days = 7
  enable_rbac_authorization = true

  tags = var.tags
}

# Key Vault Secrets

# Database connection string
resource "azurerm_key_vault_secret" "db_connection" {
  name         = "db-connection"
  key_vault_id = azurerm_key_vault.main.id
  value       = "postgres://agriwizard@${azurerm_postgresql_flexible_server.main.name}:${random_password.postgres_password.result}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/agriwizard?sslmode=require"
  content_type = "text/plain"

  depends_on = [
    azurerm_postgresql_flexible_server_database.main
  ]
}

# JWT Secret
resource "azurerm_key_vault_secret" "jwt_secret" {
  name         = "jwt-secret"
  key_vault_id = azurerm_key_vault.main.id
  value       = random_password.keyvault_password.result
}

# Service Bus connection
resource "azurerm_key_vault_secret" "servicebus_connection" {
  name         = "servicebus-connection"
  key_vault_id = azurerm_key_vault.main.id
  value       = azurerm_service_bus_namespace.main.default_primary_connection_string
}

# IoT Hub connection
resource "azurerm_key_vault_secret" "iothub_connection" {
  name         = "iothub-connection"
  key_vault_id = azurerm_key_vault.main.id
  value       = azurerm_iothub.main.primary_connection_string
}

# Storage connection
resource "azurerm_key_vault_secret" "storage_connection" {
  name         = "storage-connection"
  key_vault_id = azurerm_key_vault.main.id
  value       = azurerm_storage_account.main.primary_connection_string
}

# Application Insights connection
resource "azurerm_key_vault_secret" "appinsights_connection" {
  name         = "appinsights-connection"
  key_vault_id = azurerm_key_vault.main.id
  value       = azurerm_application_insights.main.connection_string
}

# Data source for current tenant
data "azurerm_client_config" "current" {}