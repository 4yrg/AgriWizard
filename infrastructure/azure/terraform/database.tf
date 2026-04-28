# PostgreSQL Flexible Server

resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${var.resource_group_name}-${var.environment}-postgres"
  resource_group_name  = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  sku_name            = "GP_Standard_D4s_v3"
  version              = "16"
  storage_mb          = var.postgresql_storage_mb
  backup_retention_days = var.postgresql_backup_retention_days

  administrator_login    = "agriwizard"
  administrator_password = "AgriWizard@${var.environment}123"

  # high_availability requires mode = "ZoneRedundant" or "SameZone".
  # "Disabled" is not a valid value — omit the block entirely for dev/non-HA.
  # Conditionally enable HA only when the variable is true (prod).
  dynamic "high_availability" {
    for_each = var.postgresql_high_availability ? [1] : []
    content {
      mode = "ZoneRedundant"
    }
  }

  lifecycle {
    ignore_changes = [
      zone,
      high_availability[0].standby_availability_zone,
    ]
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
  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}
