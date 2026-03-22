# =============================================================================
# AgriWizard - Development Environment Configuration
# =============================================================================
# This file contains development-specific variable values.
# Copy this file and modify for staging/production environments.
# =============================================================================

# -----------------------------------------------------------------------------
# General Configuration
# -----------------------------------------------------------------------------
resource_group_name     = "agriwizard-rg-dev"
location                = "eastus"
environment             = "dev"
project_name            = "agriwizard"

# -----------------------------------------------------------------------------
# Container Registry
# -----------------------------------------------------------------------------
acr_name                = "agriwizardacrdev"  # Must be globally unique, 5-50 chars
image_tag               = "latest"

# -----------------------------------------------------------------------------
# Container Apps Configuration
# -----------------------------------------------------------------------------
container_apps_env_name = "agriwizard-env-dev"

# Development: Lower resources for cost savings
cpu_core                = 0.25
memory_size             = 0.5
min_replicas            = 0  # Scale to zero for dev
max_replicas            = 2

# -----------------------------------------------------------------------------
# Database Configuration
# -----------------------------------------------------------------------------
postgresql_server_name  = "agriwizard-db-dev"
postgresql_admin_username = "agriadmin"
postgresql_admin_password = "ChangeMe123!@#DevPassword"  # CHANGE THIS!
postgresql_sku_name     = "Standard_B1ms"  # Burstable, cost-effective
postgresql_version      = "16"

# -----------------------------------------------------------------------------
# IoT Hub Configuration
# -----------------------------------------------------------------------------
iot_hub_name            = "agriwizard-iot-dev"

# -----------------------------------------------------------------------------
# Key Vault Configuration
# -----------------------------------------------------------------------------
key_vault_name          = "agriwizard-kv-dev"

# JWT Secret - CHANGE THIS to a random 32+ character string
# Generate with: openssl rand -base64 32
jwt_secret              = "dev-jwt-secret-change-in-production-min-32-chars!"

# -----------------------------------------------------------------------------
# API Management Configuration
# -----------------------------------------------------------------------------
apim_name               = "agriwizard-apim-dev"
apim_publisher_email    = "dev@agriwizard.com"
apim_sku_name           = "Developer_1"  # Single instance, no SLA

# -----------------------------------------------------------------------------
# Additional Tags
# -----------------------------------------------------------------------------
additional_tags = {
  CostCenter    = "IT-Development"
  Contact       = "dev-team@agriwizard.com"
  ExpiresAfter  = "2025-12-31"  # For auto-cleanup policies
}
