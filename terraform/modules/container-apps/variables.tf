variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "container_apps_env_name" {
  description = "Container Apps Environment name"
  type        = string
}

variable "container_registry_server" {
  description = "Container Registry login server"
  type        = string
}

variable "container_registry_username" {
  description = "Container Registry admin username"
  type        = string
  sensitive   = true
}

variable "container_registry_password" {
  description = "Container Registry admin password"
  type        = string
  sensitive   = true
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "db_host" {
  description = "PostgreSQL server hostname"
  type        = string
}

variable "db_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_user" {
  description = "Database admin username"
  type        = string
}

variable "db_password" {
  description = "Database admin password"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT signing secret"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.jwt_secret) >= 32
    error_message = "JWT secret must be at least 32 characters long."
  }
}

variable "iot_hub_name" {
  description = "Azure IoT Hub name"
  type        = string
}

variable "service_bus_namespace" {
  description = "Azure Service Bus namespace name"
  type        = string
}

variable "service_bus_connection" {
  description = "Service Bus connection string"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name (prod)"
  type        = string

  validation {
    condition     = contains(["prod"], var.environment)
    error_message = "Environment must be: prod."
  }
}

variable "cpu_core" {
  description = "CPU cores per container"
  type        = number
  default     = 0.5

  validation {
    condition     = var.cpu_core > 0
    error_message = "CPU core must be greater than 0."
  }
}

variable "memory_size" {
  description = "Memory in GB per container"
  type        = number
  default     = 1.0

  validation {
    condition     = var.memory_size > 0
    error_message = "Memory size must be greater than 0."
  }
}

variable "min_replicas" {
  description = "Minimum number of replicas"
  type        = number
  default     = 1

  validation {
    condition     = var.min_replicas >= 0
    error_message = "Minimum replicas cannot be negative."
  }
}

variable "max_replicas" {
  description = "Maximum number of replicas"
  type        = number
  default     = 3

  validation {
    condition     = var.max_replicas >= var.min_replicas
    error_message = "Max replicas must be greater than or equal to min replicas."
  }
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
