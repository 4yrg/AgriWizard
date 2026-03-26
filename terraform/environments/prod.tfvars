# =============================================================================
# AgriWizard - Production Environment Configuration
# =============================================================================

# -----------------------------------------------------------------------------
# General Configuration
# -----------------------------------------------------------------------------
resource_group_name = "agriwizard-rg-prod"
location            = "southeastasia"
environment         = "prod"
project_name        = "agriwizard"

# -----------------------------------------------------------------------------
# Container Registry
# -----------------------------------------------------------------------------
acr_name  = "agriwizardacrprod"
image_tag = "latest"

# -----------------------------------------------------------------------------
# Container Apps Configuration
# -----------------------------------------------------------------------------
container_apps_env_name = "agriwizard-env-prod"

cpu_core     = 1.0
memory_size  = 2.0
min_replicas = 2
max_replicas = 10

# -----------------------------------------------------------------------------
# Database Configuration
# -----------------------------------------------------------------------------
postgresql_server_name    = "agriwizard-db-prod"
postgresql_admin_username = "agriadmin"

# ❗ Provided via TF_VAR_postgresql_admin_password environment variable

postgresql_sku_name = "GP_Standard_D2s_v3"
postgresql_version  = "16"

# -----------------------------------------------------------------------------
# IoT Hub Configuration
# -----------------------------------------------------------------------------
iot_hub_name = "agriwizard-iot-prod"

# -----------------------------------------------------------------------------
# Key Vault Configuration
# -----------------------------------------------------------------------------
key_vault_name = "agri-prod-kv-mn7nij"

# ❗ Provided via TF_VAR_jwt_secret environment variable

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
