# =============================================================================
# AgriWizard - Kong Gateway on ACA
# =============================================================================
# Deploys Kong API Gateway as a container app in Azure Container Apps
# =============================================================================

# Kong Container App
resource "azurerm_container_app" "kong" {
  name                         = "${var.project_name}-kong"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = data.azurerm_resource_group.main.name
  revision_mode                = "Single"

  # Ingress configuration - External for public access
  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 8000
    transport                  = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  # Secrets
  secret {
    name  = "acr-password"
    value = azurerm_container_registry.main.admin_password
  }

  # Registry configuration
  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  # Template for container
  template {
    container {
      name   = "kong"
      image  = "kong:3.4"
      cpu    = var.kong_cpu_core
      memory = "${var.kong_memory_size}Gi"

      # Environment variables
      env {
        name  = "KONG_DATABASE"
        value = "off"
      }
      env {
        name  = "KONG_DECLARATIVE_CONFIG"
        value = file("${path.module}/kong-config/kong.yml")
      }
      env {
        name  = "KONG_PROXY_ACCESS_LOG"
        value = "/dev/stdout"
      }
      env {
        name  = "KONG_ADMIN_ACCESS_LOG"
        value = "/dev/stdout"
      }
      env {
        name  = "KONG_PROXY_ERROR_LOG"
        value = "/dev/stderr"
      }
      env {
        name  = "KONG_ADMIN_ERROR_LOG"
        value = "/dev/stderr"
      }
      env {
        name  = "KONG_ADMIN_LISTEN"
        value = "0.0.0.0:8001"
      }
      env {
        name  = "KONG_PLUGINS"
        value = "bundled,cors,rate-limiting"
      }
    }

    # scaling
    min_replicas = var.kong_min_replicas
    max_replicas = var.kong_max_replicas

    http_scale_rule {
      name                = "http-scale"
      concurrent_requests = 10
    }
  }

  # Managed Identity
  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Network - Allow Kong to access backend services
resource "azurerm_container_app_environment_stripe_network_policy" "ingress" {
  container_app_environment_id = azurerm_container_app_environment.main.id
  policy                      = "Allow"
}

resource "azurerm_container_app_environment_stripe_network_policy" "egress" {
  container_app_environment_id = azurerm_container_app_environment.main.id
  policy                      = "Allow"
}

# Outputs
output "kong_gateway_url" {
  description = "Kong Gateway HTTP URL"
  value       = "http://${azurerm_container_app.kong.ingress[0].fqdn}"
}

output "kong_gateway_external_url" {
  description = "Kong Gateway External URL"
  value       = azurerm_container_app.kong.ingress[0].fqdn
}

output "kong_admin_url" {
  description = "Kong Admin API URL"
  value       = "http://${azurerm_container_app.kong.ingress[0].fqdn}:8001"
}