# =============================================================================
# AgriWizard - Staging Environment Terraform Variables
# =============================================================================

environment = "staging"
location    = "centralindia"

# Container Registry
acr_name   = "agriwizardacr"
image_tag  = "staging"

# Container Apps
container_apps_env_name = "agriwizard-env-staging"
cpu_core                = 0.5
memory_size             = 1.0
min_replicas            = 1
max_replicas            = 3

# Database
postgresql_server_name     = "agriwizard-db-staging"
postgresql_admin_username  = "stagingadmin"
postgresql_admin_password = "StagingPass123!@#"
postgresql_sku_name       = "Standard_B1ms"
postgresql_version        = "16"

# IoT Hub
iot_hub_name = "agriwizard-iot-staging"

# Key Vault
key_vault_name = "agriwizard-kv-staging"

# JWT
jwt_secret = "staging-jwt-secret-change-in-production-min-32-chars"

# API Management
apim_name            = "agriwizard-apim-staging"
apim_publisher_email = "staging@agriwizard.com"
apim_sku_name        = "Developer_1"

# Service Bus
service_bus_name = "agriwizard-sbus-staging"

# Tags
additional_tags = {
  Environment = "staging"
  CostCenter  = "IT-Staging"
}