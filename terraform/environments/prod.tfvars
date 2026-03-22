# =============================================================================
# AgriWizard - Production Environment Configuration
# =============================================================================

# -----------------------------------------------------------------------------
# General Configuration
# -----------------------------------------------------------------------------
resource_group_name = "agriwizard-rg-prod"
location            = "centralindia"
environment         = "prod"
project_name        = "agriwizard"

# -----------------------------------------------------------------------------
# Container Registry
# -----------------------------------------------------------------------------
acr_name  = "agriwizardacrprod"
image_tag = "stable"

# -----------------------------------------------------------------------------
# Container Apps Configuration
# -----------------------------------------------------------------------------
container_apps_env_name = "agriwizard-env-prod"

cpu_core     = 1.0
memory_size  = 2.0
min_replicas  = 2
max_replicas  = 10

# -----------------------------------------------------------------------------
# Database Configuration
# -----------------------------------------------------------------------------
postgresql_server_name    = "agriwizard-db-prod"
postgresql_admin_username = "agriadmin"

# ❗ Do NOT hardcode passwords in production
# Provide via environment variable, Key Vault, or secret manager
postgresql_admin_password = "${POSTGRES_PASSWORD}"

postgresql_sku_name = "Standard_D2ads_v2"
postgresql_version   = "16"

# -----------------------------------------------------------------------------
# IoT Hub Configuration
# -----------------------------------------------------------------------------
iot_hub_name = "agriwizard-iot-prod"

# -----------------------------------------------------------------------------
# Key Vault Configuration
# -----------------------------------------------------------------------------
key_vault_name = "agriwizard-kv-prod"

# ❗ Should be injected securely (env var / secret store)
jwt_secret = "${JWT_SECRET}"

# -----------------------------------------------------------------------------
# API Management Configuration
# -----------------------------------------------------------------------------
apim_name            = "agriwizard-apim-prod"
apim_publisher_email = "production@agriwizard.com"
apim_sku_name        = "Standard_1"

# -----------------------------------------------------------------------------
# Additional Tags
# -----------------------------------------------------------------------------
additional_tags = {
  CostCenter       = "IT-Production"
  Contact          = "production-team@agriwizard.com"
  Compliance       = "SOC2"
  BackupPolicy     = "Daily"
  DisasterRecovery = "Enabled"
  Monitoring       = "24x7"
}
