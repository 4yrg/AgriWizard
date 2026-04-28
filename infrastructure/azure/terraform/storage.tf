# Azure Blob Storage

resource "azurerm_storage_account" "main" {
  name                   = "${replace(var.resource_group_name, "-", "")}${var.environment}st"
  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  account_tier         = var.storage_account_tier
  account_kind         = var.storage_account_kind
  replication          = var.storage_replication
  enable_https_traffic_only = true

  tags = var.tags
}

# Blob Service
resource "azurerm_storage_container" "uploads" {
  name                  = "uploads"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "backups" {
  name                  = "backups"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "exports" {
  name                  = "exports"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}