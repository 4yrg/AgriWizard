# =============================================================================
# Variables
# =============================================================================

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "centralindia"
}

variable "resource_group_name" {
  description = "Base resource group name"
  type        = string
  default     = "agriwizard"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project     = "AgriWizard"
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}

# =============================================================================
# Database
# =============================================================================

variable "postgresql_sku_name" {
  description = "PostgreSQL SKU name"
  type        = string
  default     = "Standard"
}

variable "postgresql_sku_tier" {
  description = "PostgreSQL SKU tier"
  type        = string
  default     = "GeneralPurpose"
}

variable "postgresql_storage_mb" {
  description = "PostgreSQL storage in MB"
  type        = number
  default     = 32768
}

variable "postgresql_backup_retention_days" {
  description = "PostgreSQL backup retention days"
  type        = number
  default     = 7
}

variable "postgresql_high_availability" {
  description = "Enable PostgreSQL HA"
  type        = bool
  default     = false
}

# =============================================================================
# Container Apps
# =============================================================================

variable "container_apps_environment" {
  description = "Container Apps environment name"
  type        = string
  default     = "agriwizard-aca"
}

variable "container_apps_location" {
  description = "Container Apps location (should match Key Vault)"
  type        = string
  default     = "centralindia"
}

# Service configurations for Container Apps
variable "iam_app_config" {
  description = "IAM service container app config"
  type = object({
    cpu          = number
    memory       = number
    min_replicas = number
    max_replicas = number
  })
  default = {
    cpu          = 0.5
    memory       = 1
    min_replicas = 1
    max_replicas = 3
  }
}

variable "hardware_app_config" {
  description = "Hardware service container app config"
  type = object({
    cpu          = number
    memory       = number
    min_replicas = number
    max_replicas = number
  })
  default = {
    cpu          = 1.0
    memory       = 2
    min_replicas = 1
    max_replicas = 5
  }
}

variable "analytics_app_config" {
  description = "Analytics service container app config"
  type = object({
    cpu          = number
    memory       = number
    min_replicas = number
    max_replicas = number
  })
  default = {
    cpu          = 1.0
    memory       = 2
    min_replicas = 1
    max_replicas = 5
  }
}

variable "weather_app_config" {
  description = "Weather service container app config"
  type = object({
    cpu          = number
    memory       = number
    min_replicas = number
    max_replicas = number
  })
  default = {
    cpu          = 0.25
    memory       = 0.5
    min_replicas = 0
    max_replicas = 2
  }
}

variable "notification_app_config" {
  description = "Notification service container app config"
  type = object({
    cpu          = number
    memory       = number
    min_replicas = number
    max_replicas = number
  })
  default = {
    cpu          = 0.5
    memory       = 1
    min_replicas = 1
    max_replicas = 3
  }
}


# =============================================================================
# Service Bus
# =============================================================================

variable "servicebus_sku" {
  description = "Service Bus SKU"
  type        = string
  default     = "Standard"
}


