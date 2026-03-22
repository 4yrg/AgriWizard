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
  type        = string
  default     = "5432"
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
}

variable "iot_hub_name" {
  description = "Azure IoT Hub name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "cpu_core" {
  description = "CPU cores per container"
  type        = number
  default     = 0.5
}

variable "memory_size" {
  description = "Memory in GB per container"
  type        = number
  default     = 1.0
}

variable "min_replicas" {
  description = "Minimum number of replicas"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum number of replicas"
  type        = number
  default     = 3
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
