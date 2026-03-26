
# =============================================================================
# AgriWizard - Azure Terraform Variables
# =============================================================================

# -----------------------------------------------------------------------------
# General Configuration
# -----------------------------------------------------------------------------

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "agriwizard-rg"
}

variable "location" {
  description = "Azure region for deployment"
  type        = string
  default     = "centralindia"
}

variable "environment" {
  description = "Environment name (prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["prod"], var.environment)
    error_message = "Environment must be: prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "agriwizard"
}

# -----------------------------------------------------------------------------
# Container Registry Configuration
# -----------------------------------------------------------------------------

variable "acr_name" {
  description = "Azure Container Registry name"
  type        = string
  default     = "agriwizardacr"

  validation {
    condition     = can(regex("^[a-zA-Z0-9]{5,50}$", var.acr_name))
    error_message = "ACR name must be 5-50 alphanumeric characters."
  }
}

variable "image_tag" {
  description = "Docker image tag for all services"
  type        = string
  default     = "latest"
}

# -----------------------------------------------------------------------------
# Container Apps Configuration
# -----------------------------------------------------------------------------

variable "container_apps_env_name" {
  description = "Container Apps Environment name"
  type        = string
  default     = "agriwizard-env"
}

variable "cpu_core" {
  description = "CPU cores per container replica"
  type        = number
  default     = 0.5

  validation {
    condition     = var.cpu_core >= 0.25 && var.cpu_core <= 4
    error_message = "CPU cores must be between 0.25 and 4."
  }
}

variable "memory_size" {
  description = "Memory in GB per container replica"
  type        = number
  default     = 1.0

  validation {
    condition     = var.memory_size >= 0.5 && var.memory_size <= 8
    error_message = "Memory must be between 0.5 and 8 GB."
  }
}

variable "min_replicas" {
  description = "Minimum number of replicas per service"
  type        = number
  default     = 1

  validation {
    condition     = var.min_replicas >= 0 && var.min_replicas <= 10
    error_message = "Min replicas must be between 0 and 10."
  }
}

variable "max_replicas" {
  description = "Maximum number of replicas per service"
  type        = number
  default     = 3

  validation {
    condition     = var.max_replicas >= var.min_replicas && var.max_replicas <= 20
    error_message = "Max replicas must be >= min_replicas and <= 20."
  }
}

# -----------------------------------------------------------------------------
# Database Configuration
# -----------------------------------------------------------------------------

variable "postgresql_server_name" {
  description = "Azure Database for PostgreSQL server name"
  type        = string
  default     = "agriwizard-db"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{2,62}[a-z0-9]$", var.postgresql_server_name))
    error_message = "PostgreSQL server name must be 3-63 characters, lowercase alphanumeric and hyphens."
  }
}

variable "postgresql_admin_username" {
  description = "PostgreSQL administrator username"
  type        = string
  default     = "agriadmin"

  validation {
    condition     = length(var.postgresql_admin_username) >= 3
    error_message = "Admin username must be at least 3 characters."
  }
}

variable "postgresql_admin_password" {
  description = "PostgreSQL administrator password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.postgresql_admin_password) >= 12
    error_message = "Password must be at least 12 characters."
  }
}

variable "postgresql_sku_name" {
  description = "PostgreSQL SKU name"
  type        = string
  default     = "Standard_B1ms"

  validation {
    condition = contains([
      "B1ms",
      "B2s",
      "B2ms",
      "B4ms",
      "Standard_B1ms",
      "Standard_B2ms",
      "Standard_B4ms",
      "Standard_D2ads_v2",
      "GP_Standard_D2s_v3"
    ], var.postgresql_sku_name)

    error_message = "Invalid PostgreSQL SKU."
  }
}

variable "postgresql_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "16"

  validation {
    condition     = contains(["14", "15", "16"], var.postgresql_version)
    error_message = "PostgreSQL version must be 14, 15, or 16."
  }
}

# -----------------------------------------------------------------------------
# IoT Hub Configuration
# -----------------------------------------------------------------------------

variable "iot_hub_name" {
  description = "Azure IoT Hub name"
  type        = string
  default     = "agriwizard-iot"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{3,50}$", var.iot_hub_name))
    error_message = "IoT Hub name must be 3-50 characters, alphanumeric and hyphens."
  }
}

# -----------------------------------------------------------------------------
# Key Vault Configuration
# -----------------------------------------------------------------------------

variable "key_vault_name" {
  description = "Azure Key Vault name"
  type        = string
  default     = "agriwizard-kv"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{3,23}$", var.key_vault_name))
    error_message = "Key Vault name must be 4-24 characters, start with a letter."
  }
}

variable "jwt_secret" {
  description = "JWT signing secret"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.jwt_secret) >= 32
    error_message = "JWT secret must be at least 32 characters."
  }
}

# -----------------------------------------------------------------------------
# API Management Configuration
# -----------------------------------------------------------------------------

variable "apim_name" {
  description = "API Management service name"
  type        = string
  default     = "agriwizard-apim"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{3,49}$", var.apim_name))
    error_message = "APIM name must be 4-50 characters, start with a letter."
  }
}

variable "apim_publisher_email" {
  description = "API Management publisher email"
  type        = string
  default     = "admin@agriwizard.com"

  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.apim_publisher_email))
    error_message = "Must be a valid email address."
  }
}

variable "apim_sku_name" {
  description = "API Management SKU"
  type        = string
  default     = "Developer_1"

  validation {
    condition = contains([
      "Developer_1",
      "Basic_1",
      "Standard_1",
      "Premium_1"
    ], var.apim_sku_name)

    error_message = "Invalid APIM SKU."
  }
}

# -----------------------------------------------------------------------------
# Service Bus Configuration
# -----------------------------------------------------------------------------

variable "service_bus_name" {
  description = "Azure Service Bus namespace name"
  type        = string
  default     = "agriwizard-sbus"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{3,62}[a-zA-Z0-9]$", var.service_bus_name))
    error_message = "Service Bus name must be 6-63 characters, start/end with alphanumeric."
  }
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
