# =============================================================================
# AgriWizard - Production Environment Terraform Variables
# =============================================================================

environment = "prod"
location    = "centralindia"

# Container Registry
acr_name   = "agriwizard"
image_tag  = "v1"

# Container Apps
container_apps_env_name = "agriwizard-env"
cpu_core                = 0.25
memory_size             = 0.5
min_replicas            = 1
max_replicas            = 2

# JWT
jwt_secret = "prod-ultra-secure-jwt-secret-min-32-characters-long"

# Key Vault
key_vault_name = "agriwizard-kv"

# Service Bus
service_bus_name = "agriwizard-sbus"

# VM Configuration
vm_username = "kongadmin"
vm_password = "KongAdmin2026!"
vm_size     = "Standard_B1s"

# Tags
additional_tags = {
  Environment = "production"
  CostCenter  = "IT-Production"
}