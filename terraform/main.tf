terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.0"
    }
  }

  # Backend configuration for remote state storage
  # Uncomment and configure for production use
  # backend "azurerm" {
  #   resource_group_name  = "agriwizard-tfstate-rg"
  #   storage_account_name = "tfstateagriwizard"
  #   container_name       = "tfstate"
  #   key                  = "agriwizard.terraform.tfstate"
  # }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }

  # Use Azure CLI authentication
  # Alternatively, set ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID
}

provider "random" {}

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

  # Container Apps configuration
  container_apps_config = {
    cpu_core    = var.cpu_core
    memory_size = var.memory_size
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas
  }
}

# Data source to get current client configuration
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = local.common_tags

  lifecycle {
    prevent_destroy = false
  }
}

# Log Analytics Workspace for centralized logging
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.prefix}-log"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.common_tags
}

# Application Insights for application monitoring
resource "azurerm_application_insights" "main" {
  name                = "${local.prefix}-appinsights"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "other"

  tags = local.common_tags
}

# Azure Container Registry
resource "azurerm_container_registry" "main" {
  name                = var.acr_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  admin_enabled       = true

  # Enable data endpoint for better performance
  data_endpoint_enabled = true

  # Retention policy
  retention_policy_in_days = 7

  tags = local.common_tags

  # Zone redundancy for production
  zone_redundancy_enabled = var.environment == "prod" ? true : false
}

# Container Apps Environment
resource "azurerm_container_app_environment" "main" {
  name                       = var.container_apps_env_name
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  # Infrastructure configuration
  infrastructure_subnet_id   = null # Use managed environment
  internal_load_balancer_enabled = false

  tags = local.common_tags

  depends_on = [
    azurerm_log_analytics_workspace.main
  ]
}

# Azure Key Vault for secret management
resource "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
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
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

# Azure Database for PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "main" {
  name                = var.postgresql_server_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  version             = var.postgresql_version
  delegated_subnet_id = null # Public access for now, can be configured for private
  private_dns_zone_id = null
  zone                = "1"

  # Administrator credentials
  administrator_username = var.postgresql_admin_username
  administrator_password = var.postgresql_admin_password

  # SKU configuration
  sku_name = var.postgresql_sku_name

  # Storage configuration
  storage_mb           = 32768 # 32GB
  auto_grow_enabled    = true
  backup_retention_days = 7
  geo_redundant_backup_enabled = var.environment == "prod" ? true : false

  # High availability (production only)
  high_availability {
    mode                      = var.environment == "prod" ? "ZoneRedundant" : "Disabled"
    standby_availability_zone = var.environment == "prod" ? "2" : null
  }

  # Maintenance window
  maintenance_window {
    day_of_week  = 0
    start_hour   = 2
    start_minute = 0
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [
      administrator_password # Manage password via Key Vault
    ]
  }
}

# PostgreSQL Database
resource "azurerm_postgresql_flexible_server_database" "agriwizard" {
  name      = "agriwizard"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "English_United States.1252"
}

# IoT Hub for MQTT communication
resource "azurerm_iothub" "main" {
  name                = var.iot_hub_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "S1"
  capacity            = 1

  # Event Hub endpoints configuration
  event_hub {
    name                      = "events"
    partition_count           = 2
    retention_time_in_days    = 1
    partition_ids             = ["0", "1"]
  }

  # IP Filter (allow all for now, restrict in production)
  ip_filter {
    name  = "AllowAll"
    ip_mask = "0.0.0.0/0"
    action = "Accept"
  }

  tags = local.common_tags
}

# IoT Hub Consumer Group
resource "azurerm_iothub_consumer_group" "main" {
  name            = "agriwizard-consumer"
  iothub_id       = azurerm_iothub.main.id
  event_hub_endpoint_name = "events"
}

# API Management Service
resource "azurerm_api_management" "main" {
  name                = var.apim_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  publisher_name      = "AgriWizard Team"
  publisher_email     = var.apim_publisher_email
  sku_name            = var.apim_sku_name

  # Identity for Key Vault integration
  identity {
    type = "SystemAssigned"
  }

  # Virtual network configuration (optional)
  # virtual_network_type = "Internal" # or "External"

  tags = local.common_tags

  lifecycle {
    ignore_changes = [
      tags["LastModified"]
    ]
  }
}

# API Management - AgriWizard API
resource "azurerm_api_management_api" "agriwizard" {
  name                = "agriwizard-api"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  revision            = "1"
  display_name        = "AgriWizard API"
  path                = "api/v1"
  protocols           = ["https"]
  service_url         = null
  subscription_required = true

  # Import OpenAPI specification if available
  # import {
  #   content_format = "openapi"
  #   content_value  = file("${path.module}/swagger.yaml")
  # }
}

# API Management - Products
resource "azurerm_api_management_product" "agriwizard" {
  product_id            = "agriwizard-product"
  api_management_name   = azurerm_api_management.main.name
  resource_group_name   = azurerm_resource_group.main.name
  display_name          = "AgriWizard Product"
  description           = "Access to AgriWizard microservices APIs"
  subscription_required = true
  requires_approval     = false
  published             = true
}

# API Management - Product API Association
resource "azurerm_api_management_product_api" "main" {
  product_id          = azurerm_api_management_product.agriwizard.product_id
  api_id              = azurerm_api_management_api.agriwizard.api_id
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
}
