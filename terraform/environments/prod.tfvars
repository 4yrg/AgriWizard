# =============================================================================
# AgriWizard - Production Environment Configuration
# =============================================================================
# This file contains production-specific variable values.
# Review and customize all values before deploying to production.
# =============================================================================

# -----------------------------------------------------------------------------
# General Configuration
# -----------------------------------------------------------------------------
resource_group_name     = "agriwizard-rg-prod"
location                = "eastus2"  # Use different region for prod
environment             = "prod"
project_name            = "agriwizard"

# -----------------------------------------------------------------------------
# Container Registry
# -----------------------------------------------------------------------------
acr_name                = "agriwizardacrprod"  # Must be globally unique
image_tag               = "stable"  # Use stable tag for production

# -----------------------------------------------------------------------------
# Container Apps Configuration
# -----------------------------------------------------------------------------
container_apps_env_name = "agriwizard-env-prod"

# Production: Higher resources for performance
cpu_core                = 1.0
memory_size             = 2.0
min_replicas            = 2  # High availability
max_replicas            = 10 # Autoscaling for load spikes

# -----------------------------------------------------------------------------
# Database Configuration
# -----------------------------------------------------------------------------
postgresql_server_name  = "agriwizard-db-prod"
postgresql_admin_username = "agriadmin"
# IMPORTANT: Store this password in Azure Key Vault or use managed identity
postgresql_admin_password = "CHANGE-THIS-PROD-PASSWORD-123!@#"  # CHANGE THIS!
postgresql_sku_name     = "Standard_D2ads_v2"  # Production-grade
postgresql_version      = "16"

# -----------------------------------------------------------------------------
# IoT Hub Configuration
# -----------------------------------------------------------------------------
iot_hub_name            = "agriwizard-iot-prod"

# -----------------------------------------------------------------------------
# Key Vault Configuration
# -----------------------------------------------------------------------------
key_vault_name          = "agriwizard-kv-prod"

# IMPORTANT: Generate a secure random JWT secret
# Use: openssl rand -base64 32
jwt_secret              = "prod-jwt-secret-GENERATE-SECURE-RANDOM-STRING-HERE!"

# -----------------------------------------------------------------------------
# API Management Configuration
# -----------------------------------------------------------------------------
apim_name               = "agriwizard-apim-prod"
apim_publisher_email    = "production@agriwizard.com"
apim_sku_name           = "Standard_1"  # Multi-region, SLA-backed

# -----------------------------------------------------------------------------
# Additional Tags
# -----------------------------------------------------------------------------
additional_tags = {
  CostCenter      = "IT-Production"
  Contact         = "production-team@agriwizard.com"
  Compliance      = "SOC2"
  BackupPolicy    = "Daily"
  DisasterRecovery = "Enabled"
  Monitoring       = "24x7"
}
