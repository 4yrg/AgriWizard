# =============================================================================
# AgriWizard - Production Environment Terraform Variables
# =============================================================================

environment = "prod"
location    = "centralindia"

# Project
project_name = "agriwizard"

# Container Registry
acr_name   = "agriwizardacr"
image_tag  = "latest"

# Container Apps Environment
container_apps_env_name = "agriwizard-env"

# Container Apps Scaling
cpu_core    = 0.5
memory_size = 1.0
min_replicas = 1
max_replicas = 3

# Kong Gateway
kong_cpu_core    = 0.5
kong_memory_size = 1.0
kong_min_replicas = 1
kong_max_replicas = 3

# Database
postgresql_server_name     = "agriwizard-db-prod"
postgresql_admin_username  = "prodadmin"
postgresql_admin_password = "ProdSecure@123"
postgresql_sku_name       = "Standard_B2s"
postgresql_version        = "16"

# IoT Hub
iot_hub_name = "agriwizard-iot-prod"

# Key Vault
key_vault_name = "agriwizard-kv-prod"

# JWT
jwt_secret = "prod-jwt-secret-minimum-32-characters-long"

# API Management
apim_name            = "agriwizard-apim-prod"
apim_publisher_email = "admin@agriwizard.com"
apim_sku_name        = "Developer_1"

# RabbitMQ
rabbitmq_default_user     = "agriwizard"
rabbitmq_default_pass     = "RabbitMQProd@123"
rabbitmq_cpu_core         = 0.5
rabbitmq_memory_size     = 1.0
rabbitmq_min_replicas    = 1
rabbitmq_max_replicas    = 1

# Tags
additional_tags = {
  Environment = "production"
  CostCenter  = "IT-Production"
}