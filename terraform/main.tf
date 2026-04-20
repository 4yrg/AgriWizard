# =============================================================================
# AgriWizard - Main Terraform Configuration
# =============================================================================
# This file creates the core Azure infrastructure for AgriWizard.
# =============================================================================

# Local values for consistent naming
locals {
  common_tags = {
    Project     = "AgriWizard"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Application = "Smart Greenhouse Management"
    Owner       = "AgriWizard Team"
    CostCenter  = "IT-Cloud"
  }

  # Resource name prefix
  prefix = "${var.project_name}-${var.environment}"
}

# Data source to get current client configuration
data "azurerm_client_config" "current" {}

# Use existing resource group
data "azurerm_resource_group" "main" {
  name = "agriwizard-rg"
}

# Log Analytics Workspace for centralized logging
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.prefix}-log"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.common_tags
}

# Application Insights for application monitoring
resource "azurerm_application_insights" "main" {
  name                = "${local.prefix}-appinsights"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "other"

  tags = local.common_tags
}

# Azure Container Registry
resource "azurerm_container_registry" "main" {
  name                = var.acr_name
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "Standard"
  admin_enabled       = true

  # Enable data endpoint for better performance
  data_endpoint_enabled = false

  tags = local.common_tags

  zone_redundancy_enabled = false
}

# Container Apps Environment
resource "azurerm_container_app_environment" "main" {
  name                       = var.container_apps_env_name
  location                   = data.azurerm_resource_group.main.location
  resource_group_name        = data.azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  tags = local.common_tags

  depends_on = [
    azurerm_log_analytics_workspace.main
  ]
}

# Azure Key Vault for secret management
resource "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Soft delete and purge protection
  soft_delete_retention_days = 7
  purge_protection_enabled   = true

  # Network security (can be configured for private access)
  public_network_access_enabled = true

  tags = local.common_tags
}

# Key Vault Access Policy for current user
resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Purge",
    "Recover",
    "Backup",
    "Restore"
  ]

  certificate_permissions = [
    "Get",
    "List",
    "Create",
    "Delete",
    "Purge",
    "Recover",
    "Backup",
    "Restore"
  ]
}

# Key Vault Access Policy for Container Apps
resource "azurerm_key_vault_access_policy" "container_apps" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.container_apps.principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# User Assigned Identity for Container Apps
resource "azurerm_user_assigned_identity" "container_apps" {
  name                = "${local.prefix}-identity"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  tags = local.common_tags
}

# Azure Database for PostgreSQL Flexible Server (commented out for deployment)
# resource "azurerm_postgresql_flexible_server" "main" {
#   name                = var.postgresql_server_name
#   resource_group_name = data.azurerm_resource_group.main.name
#   location            = var.location
#   version             = var.postgresql_version

#   # Administrator credentials
#   administrator_login    = var.postgresql_admin_username
#   administrator_password = var.postgresql_admin_password

#   # SKU configuration
#   sku_name = var.postgresql_sku_name

#   # Storage configuration
#   storage_mb        = 32768 # 32GB
#   auto_grow_enabled = true

#   tags = local.common_tags

#   lifecycle {
#     ignore_changes = [zone]
#   }
# }

# PostgreSQL Database (commented out)
# resource "azurerm_postgresql_flexible_server_database" "agriwizard" {
#   name      = "agriwizard"
#   server_id = azurerm_postgresql_flexible_server.main.id
#   collation = "en_US.utf8"
#   charset   = "UTF8"
# }

# IoT Hub for MQTT communication (commented out)
# resource "azurerm_iothub" "main" {
#   name                = var.iot_hub_name
#   location            = data.azurerm_resource_group.main.location
#   resource_group_name = data.azurerm_resource_group.main.name
#
#   sku {
#     name     = "S1"
#     capacity = 1
#   }
#
#   tags = local.common_tags
# }

# IoT Hub Consumer Group (commented out)
# resource "azurerm_iothub_consumer_group" "main" {
#   name                   = "agriwizard-consumer"
#   iothub_name            = azurerm_iothub.main.name
#   resource_group_name    = data.azurerm_resource_group.main.name
#   eventhub_endpoint_name = "events"
# }

# API Management Service (commented out - using Kong instead)
# resource "azurerm_api_management" "main" {
#   name                = var.apim_name
#   location            = data.azurerm_resource_group.main.location
#   resource_group_name = data.azurerm_resource_group.main.name
#   publisher_name      = "AgriWizard Team"
#   publisher_email     = var.apim_publisher_email
#   sku_name            = var.apim_sku_name
#
#   # Identity for Key Vault integration
#   identity {
#     type = "SystemAssigned"
#   }
#
#   tags = local.common_tags
#
#   lifecycle {
#     ignore_changes = [
#       tags["LastModified"]
#     ]
#   }
# }

# API Management - AgriWizard API (commented out)
# resource "azurerm_api_management_api" "agriwizard" {
#   name                  = "agriwizard-api"
#   resource_group_name   = data.azurerm_resource_group.main.name
#   api_management_name   = azurerm_api_management.main.name
#   revision              = "1"
#   display_name          = "AgriWizard API"
#   path                  = "api/v1"
#   protocols             = ["https"]
#   service_url           = null
#   subscription_required = true
# }

# API Management - Products (commented out)
# resource "azurerm_api_management_product" "agriwizard" {
#   product_id            = "agriwizard-product"
#   api_management_name   = azurerm_api_management.main.name
#   resource_group_name   = data.azurerm_resource_group.main.name
#   display_name          = "AgriWizard Product"
#   description           = "Access to AgriWizard microservices APIs"
#   subscription_required = true
#   approval_required     = false
#   published             = true
# }

# API Management - Product API Association (commented out)
# resource "azurerm_api_management_product_api" "main" {
#   product_id          = azurerm_api_management_product.agriwizard.product_id
#   api_name            = azurerm_api_management_api.agriwizard.name
#   api_management_name = azurerm_api_management.main.name
#   resource_group_name = data.azurerm_resource_group.main.name
# }

# =============================================================================
# Azure Service Bus (Event-Driven Architecture)
# =============================================================================

# Service Bus Namespace
resource "azurerm_servicebus_namespace" "main" {
  name                = var.service_bus_name
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "Standard"

  tags = local.common_tags
}

# Service Bus Topic: telemetry-events
resource "azurerm_servicebus_topic" "telemetry_events" {
  name                = "telemetry-events"
  namespace_id        = azurerm_servicebus_namespace.main.id
  auto_delete_on_idle = "PT168H"
}

# Service Bus Topic: automation-commands
resource "azurerm_servicebus_topic" "automation_commands" {
  name                = "automation-commands"
  namespace_id        = azurerm_servicebus_namespace.main.id
  auto_delete_on_idle = "PT168H"
}

# Service Bus Topic: notifications
resource "azurerm_servicebus_topic" "notifications" {
  name                = "notifications"
  namespace_id        = azurerm_servicebus_namespace.main.id
  auto_delete_on_idle = "PT168H"
}

# Service Bus Authorization Rule (for Container Apps)
resource "azurerm_servicebus_namespace_authorization_rule" "container_apps" {
  name         = "container-apps-listen"
  namespace_id = azurerm_servicebus_namespace.main.id

  listen = true
  send   = true
  manage = false
}

# Service Bus Subscription: telemetry-events (for analytics service)
resource "azurerm_servicebus_subscription" "analytics_telemetry" {
  name               = "analytics-service"
  topic_id           = azurerm_servicebus_topic.telemetry_events.id
  max_delivery_count = 10
  lock_duration      = "PT30S"
}

# Service Bus Subscription: notifications (for notification service)
resource "azurerm_servicebus_subscription" "notification_handler" {
  name               = "notification-service"
  topic_id           = azurerm_servicebus_topic.notifications.id
  max_delivery_count = 10
  lock_duration      = "PT30S"
}

# Service Bus Subscription: automation-commands (for hardware service)
resource "azurerm_servicebus_subscription" "hardware_commands" {
  name               = "hardware-service"
  topic_id           = azurerm_servicebus_topic.automation_commands.id
  max_delivery_count = 10
  lock_duration      = "PT30S"
}
