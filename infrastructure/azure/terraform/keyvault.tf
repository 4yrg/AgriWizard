# Key Vault for secrets management

resource "azurerm_key_vault" "main" {
  name                = "${var.resource_group_name}-${var.environment}-kv"
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  tenant_id          = data.azurerm_client_config.current.tenant_id
  sku_name           = "standard"
  soft_delete_retention_days = 7
  enable_rbac_authorization = true

  tags = var.tags
}

# Key Vault Access Policy for current user (for deployment)
resource "azurerm_key_vault_access_policy" "deployer" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id   = data.azurerm_client_config.current.tenant_id
  object_id   = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete"
  ]

  key_permissions = [
    "Get",
    "List"
  ]
}