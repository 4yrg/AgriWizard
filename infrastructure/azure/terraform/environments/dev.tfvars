# Development Environment Variables

environment         = "dev"
location            = "centralindia"
resource_group_name = "agriwizard"

# Database
postgresql_sku_tier          = "GeneralPurpose"
postgresql_storage_mb        = 32768
postgresql_high_availability = false
postgresql_backup_retention_days = 7

# Container Apps
container_apps_environment = "agriwizard-dev-aca"
iam_app_config = {
  cpu        = 0.5
  memory    = 1
  min_replicas = 1
  max_replicas = 3
}
hardware_app_config = {
  cpu        = 0.5
  memory    = 1
  min_replicas = 1
  max_replicas = 3
}
analytics_app_config = {
  cpu        = 0.5
  memory    = 1
  min_replicas = 1
  max_replicas = 3
}
weather_app_config = {
  cpu        = 0.25
  memory    = 0.5
  min_replicas = 0
  max_replicas = 2
}
notification_app_config = {
  cpu        = 0.25
  memory    = 0.5
  min_replicas = 1
  max_replicas = 2
}

# API Management
apim_sku = "Developer"

# Service Bus
servicebus_sku = "Standard"

# IoT Hub
iothub_sku   = "F1"
iothub_units = 1

# Storage
storage_account_tier   = "Standard"
storage_account_kind   = "StorageV2"
storage_replication    = "LRS"

# Tags
tags = {
  Project     = "AgriWizard"
  ManagedBy   = "Terraform"
  Environment = "dev"
}