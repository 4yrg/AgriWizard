# =============================================================================
# AgriWizard - Development Environment Terraform Variables
# =============================================================================

environment = "dev"
location    = "centralindia"

# Container Registry
acr_name   = "agriwizardacr"
image_tag  = "dev"

# Container Apps
container_apps_env_name = "agriwizard-env-dev"
cpu_core                = 0.25
memory_size             = 0.5
min_replicas            = 0
max_replicas            = 2

# Database
postgresql_server_name     = "agriwizard-db-dev"
postgresql_admin_username  = "devadmin"
postgresql_admin_password = "DevPass123!@#"
postgresql_sku_name       = "Standard_B1ms"
postgresql_version        = "16"

# IoT Hub
iot_hub_name = "agriwizard-iot-dev"

# Key Vault
key_vault_name = "agriwizard-kv-dev"

# JWT
jwt_secret = "dev-jwt-secret-change-in-production-min-32-chars"

# API Management
apim_name            = "agriwizard-apim-dev"
apim_publisher_email = "dev@agriwizard.com"
apim_sku_name        = "Developer_1"

# Service Bus
service_bus_name = "agriwizard-sbus-dev"

# Tags
additional_tags = {
  Environment = "development"
  CostCenter  = "IT-Dev"
}