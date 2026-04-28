# Azure Resource Group

resource "azurerm_resource_group" "main" {
  name     = "${var.resource_group_name}-${var.environment}-rg"
  location = var.location

  tags = merge(var.tags, {
    Environment = var.environment
  })
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.resource_group_name}-${var.environment}-law"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_days      = 30

  tags = var.tags
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "${var.resource_group_name}-${var.environment}-ai"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "other"
  workspace_id         = azurerm_log_analytics_workspace.main.id

  tags = var.tags
}