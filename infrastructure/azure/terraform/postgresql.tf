# Azure Database for PostgreSQL Flexible Server

resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${var.resource_group_name}-${var.environment}-postgres"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  sku_name               = var.postgresql_sku_tier == "GeneralPurpose" ? "GP_Standard_D4s_v3" : "MO_Standard_D4s_v3"
  tier                  = var.postgresql_sku_tier
  version                = "16"
  storage_mb              = var.postgresql_storage_mb
  admin_username         = "agriwizard"
  admin_password        = random_password.postgres_password.result
  backup_retention_days = var.postgresql_backup_retention_days
  geo_redundant_backup  = var.postgresql_high_availability ? "Enabled" : "Disabled"
  high_availability {
    mode = var.postgresql_high_availability ? "ZoneRedundant" : "Disabled"
  }

  tags = var.tags
}

# Database (within PostgreSQL server)
resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = "agriwizard"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Firewall rule to allow Azure services
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name                = "allow-azure-services"
  server_id           = azurerm_postgresql_flexible_server.main.id
  start_ip_address    = "0.0.0.0"
  end_ip_address     = "0.0.0.0"
}

# Firewall rule for developer access (optional - restrict in production)
resource "azurerm_postgresql_flexible_server_firewall_rule" "developer_ip" {
  count              = var.environment == "prod" ? 0 : 1
  name               = "allow-developer-ip"
  server_id          = azurerm_postgresql_flexible_server.main.id
  start_ip_address  = var.environment == "prod" ? "" : "<your-ip>"
  end_ip_address    = var.environment == "prod" ? "" : "<your-ip>"
}