# PostgreSQL Flexible Server

resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${var.resource_group_name}-${var.environment}-postgres"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  sku_name               = "GP_Standard_D4s_v3"
  tier                  = var.postgresql_sku_tier
  version                = "16"
  storage_mb              = var.postgresql_storage_mb
  admin_username         = "agriwizard"
  admin_password        = "AgriWizard@${var.environment}123"  # Change in production
  backup_retention_days = var.postgresql_backup_retention_days
  geo_redundant_backup  = "Disabled"

  high_availability {
    mode = "Disabled"
  }

  tags = var.tags
}

# Database
resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = "agriwizard"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Firewall rule - allow all Azure services
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name                = "allow-azure-services"
  server_id           = azurerm_postgresql_flexible_server.main.id
  start_ip_address    = "0.0.0.0"
  end_ip_address     = "0.0.0.0"
}