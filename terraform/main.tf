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

# Azure Database for PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "main" {
  name                = var.postgresql_server_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  version             = var.postgresql_version

  # Administrator credentials
  administrator_login    = var.postgresql_admin_username
  administrator_password = var.postgresql_admin_password

  # SKU configuration
  sku_name = var.postgresql_sku_name

  # Storage configuration
  storage_mb        = 32768 # 32GB
  auto_grow_enabled = true

  # High availability
  high_availability {
    mode = "Disabled"
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [zone]
  }
}

# PostgreSQL Database
resource "azurerm_postgresql_flexible_server_database" "agriwizard" {
  name      = "agriwizard"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

# PostgreSQL Firewall Rule - Allow Azure resources
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_access" {
  name     = "AllowAzureResources"
  server_id = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# PostgreSQL Firewall Rule - Allow all IP (for development/staging)
resource "azurerm_postgresql_flexible_server_firewall_rule" "all_access" {
  name     = "AllowAll"
  server_id = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

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
# RabbitMQ (Event-Driven Architecture)
# =============================================================================

# RabbitMQ Container App
resource "azurerm_container_app" "rabbitmq" {
  name                         = "${var.project_name}-rabbitmq"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = data.azurerm_resource_group.main.name
  revision_mode                = "Single"

  # Ingress - Internal only (not exposed publicly)
  ingress {
    allow_insecure_connections = false
    external_enabled           = false
    target_port                = 5672
    transport                  = "tcp"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  # Secrets
  secret {
    name  = "rabbitmq-default-user"
    value = var.rabbitmq_default_user
  }

  secret {
    name  = "rabbitmq-default-pass"
    value = var.rabbitmq_default_pass
  }

  # Registry configuration (using public image, no ACR needed)
  # template for container
  template {
    container {
      name   = "rabbitmq"
      image  = "rabbitmq:3.12-management"
      cpu    = var.rabbitmq_cpu_core
      memory = "${var.rabbitmq_memory_size}Gi"

      # Environment variables
      env {
        name  = "RABBITMQ_DEFAULT_USER"
        value = var.rabbitmq_default_user
      }
      env {
        name  = "RABBITMQ_DEFAULT_PASS"
        value = var.rabbitmq_default_pass
      }
      env {
        name  = "RABBITMQ_DEFAULT_VHOST"
        value = "/"
      }
      env {
        name  = "RABBITMQ_SERVER_ADDITIONAL_ERL_ARGS"
        value = "-rabbit log_levels [{connection,info}]"
      }
    }

    # Scaling
    min_replicas = var.rabbitmq_min_replicas
    max_replicas = var.rabbitmq_max_replicas
  }

  # Managed Identity
  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# RabbitMQ Management UI Ingress
resource "azurerm_container_app" "rabbitmq_mgmt" {
  name                         = "${var.project_name}-rabbitmq-mgmt"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = data.azurerm_resource_group.main.name
  revision_mode                = "Single"

  # Ingress - External for management UI
  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 15672
    transport                  = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  # Registry configuration (not needed for public image)
  # template for container
  template {
    container {
      name   = "rabbitmq-mgmt"
      image  = "rabbitmq:3.12-management"
      cpu    = var.rabbitmq_cpu_core
      memory = "${var.rabbitmq_memory_size}Gi"

      # Environment variables
      env {
        name  = "RABBITMQ_DEFAULT_USER"
        value = var.rabbitmq_default_user
      }
      env {
        name  = "RABBITMQ_DEFAULT_PASS"
        value = var.rabbitmq_default_pass
      }
      env {
        name  = "RABBITMQ_MANAGEMENT_HTTP_PORT"
        value = "15672"
      }
    }

    min_replicas = 1
    max_replicas = 1
  }

  # Managed Identity
  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Outputs for RabbitMQ
output "rabbitmq_url" {
  description = "RabbitMQ AMQP URL"
  value       = "amqp://${var.rabbitmq_default_user}:${var.rabbitmq_default_pass}@${azurerm_container_app.rabbitmq.ingress[0].fqdn}:5672"
}

output "rabbitmq_management_url" {
  description = "RabbitMQ Management UI URL"
  value       = "http://${azurerm_container_app.rabbitmq_mgmt.ingress[0].fqdn}:15672"
}
