# IAM Service Container App
resource "azurerm_container_app" "iam_service" {
  name                         = "${var.environment}-iam-service"
  container_app_environment_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.App/managedEnvironments/${var.container_apps_env_name}"
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  # Ingress configuration - Internal only, accessed via API Gateway
  ingress {
    allow_insecure_connections = false
    external_enabled           = false
    target_port                = 8081
    transport                  = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  # Registry configuration
  registry {
    server   = var.container_registry_server
    username = var.container_registry_username
    password = var.container_registry_password
  }

  # Template for container
  template {
    container {
      name   = "iam-service"
      image  = "${var.container_registry_server}/agriwizard-iam-service:${var.image_tag}"
      cpu    = var.cpu_core
      memory = "${var.memory_size}Gi"

      # Environment variables
      env {
        name  = "PORT"
        value = "8081"
      }
      env {
        name  = "DB_HOST"
        value = var.db_host
      }
      env {
        name  = "DB_PORT"
        value = var.db_port
      }
      env {
        name  = "DB_USER"
        value = var.db_user
      }
      env {
        name  = "DB_PASSWORD"
        value = var.db_password
      }
      env {
        name  = "DB_NAME"
        value = var.db_name
      }
      env {
        name  = "JWT_SECRET"
        value = var.jwt_secret
      }
      env {
        name  = "JWT_TTL_HOURS"
        value = "24"
      }
      env {
        name  = "GIN_MODE"
        value = "release"
      }
    }

    # Scaling rules
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    # Scale based on HTTP requests
    scale_rule {
      name = "http-scale-rule"
      custom {
        type  = "http"
        value = "10"
      }
    }
  }

  # Managed Identity
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Hardware Service Container App
resource "azurerm_container_app" "hardware_service" {
  name                         = "${var.environment}-hardware-service"
  container_app_environment_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.App/managedEnvironments/${var.container_apps_env_name}"
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  # Ingress configuration - Internal only
  ingress {
    allow_insecure_connections = false
    external_enabled           = false
    target_port                = 8082
    transport                  = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  # Registry configuration
  registry {
    server   = var.container_registry_server
    username = var.container_registry_username
    password = var.container_registry_password
  }

  # Template for container
  template {
    container {
      name   = "hardware-service"
      image  = "${var.container_registry_server}/agriwizard-hardware-service:${var.image_tag}"
      cpu    = var.cpu_core
      memory = "${var.memory_size}Gi"

      # Environment variables
      env {
        name  = "PORT"
        value = "8082"
      }
      env {
        name  = "DB_HOST"
        value = var.db_host
      }
      env {
        name  = "DB_PORT"
        value = var.db_port
      }
      env {
        name  = "DB_USER"
        value = var.db_user
      }
      env {
        name  = "DB_PASSWORD"
        value = var.db_password
      }
      env {
        name  = "DB_NAME"
        value = var.db_name
      }
      env {
        name  = "JWT_SECRET"
        value = var.jwt_secret
      }
      env {
        name  = "MQTT_BROKER"
        value = "ssl://${var.iot_hub_name}.azure-devices.net:8883"
      }
      env {
        name  = "ANALYTICS_SERVICE_URL"
        value = "http://${var.environment}-analytics-service:8083"
      }
      env {
        name  = "GIN_MODE"
        value = "release"
      }
    }

    # Scaling rules
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    # Scale based on HTTP requests
    scale_rule {
      name = "http-scale-rule"
      custom {
        type  = "http"
        value = "10"
      }
    }
  }

  # Managed Identity
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Analytics Service Container App
resource "azurerm_container_app" "analytics_service" {
  name                         = "${var.environment}-analytics-service"
  container_app_environment_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.App/managedEnvironments/${var.container_apps_env_name}"
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  # Ingress configuration - Internal only
  ingress {
    allow_insecure_connections = false
    external_enabled           = false
    target_port                = 8083
    transport                  = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  # Registry configuration
  registry {
    server   = var.container_registry_server
    username = var.container_registry_username
    password = var.container_registry_password
  }

  # Template for container
  template {
    container {
      name   = "analytics-service"
      image  = "${var.container_registry_server}/agriwizard-analytics-service:${var.image_tag}"
      cpu    = var.cpu_core
      memory = "${var.memory_size}Gi"

      # Environment variables
      env {
        name  = "PORT"
        value = "8083"
      }
      env {
        name  = "DB_HOST"
        value = var.db_host
      }
      env {
        name  = "DB_PORT"
        value = var.db_port
      }
      env {
        name  = "DB_USER"
        value = var.db_user
      }
      env {
        name  = "DB_PASSWORD"
        value = var.db_password
      }
      env {
        name  = "DB_NAME"
        value = var.db_name
      }
      env {
        name  = "JWT_SECRET"
        value = var.jwt_secret
      }
      env {
        name  = "HARDWARE_SERVICE_URL"
        value = "http://${var.environment}-hardware-service:8082"
      }
      env {
        name  = "WEATHER_SERVICE_URL"
        value = "http://${var.environment}-weather-service:8084"
      }
      env {
        name  = "GIN_MODE"
        value = "release"
      }
    }

    # Scaling rules
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    # Scale based on HTTP requests
    scale_rule {
      name = "http-scale-rule"
      custom {
        type  = "http"
        value = "10"
      }
    }
  }

  # Managed Identity
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Weather Service Container App
resource "azurerm_container_app" "weather_service" {
  name                         = "${var.environment}-weather-service"
  container_app_environment_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.App/managedEnvironments/${var.container_apps_env_name}"
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  # Ingress configuration - Internal only
  ingress {
    allow_insecure_connections = false
    external_enabled           = false
    target_port                = 8084
    transport                  = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  # Registry configuration
  registry {
    server   = var.container_registry_server
    username = var.container_registry_username
    password = var.container_registry_password
  }

  # Template for container
  template {
    container {
      name   = "weather-service"
      image  = "${var.container_registry_server}/agriwizard-weather-service:${var.image_tag}"
      cpu    = var.cpu_core
      memory = "${var.memory_size}Gi"

      # Environment variables
      env {
        name  = "PORT"
        value = "8084"
      }
      env {
        name  = "JWT_SECRET"
        value = var.jwt_secret
      }
      env {
        name  = "USE_MOCK"
        value = "true"
      }
      env {
        name  = "LOCATION_LAT"
        value = "6.9271"
      }
      env {
        name  = "LOCATION_LON"
        value = "79.8612"
      }
      env {
        name  = "LOCATION_CITY"
        value = "Colombo"
      }
      env {
        name  = "GIN_MODE"
        value = "release"
      }
    }

    # Scaling rules
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    # Scale based on HTTP requests
    scale_rule {
      name = "http-scale-rule"
      custom {
        type  = "http"
        value = "10"
      }
    }
  }

  # Managed Identity
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Notification Service Container App
resource "azurerm_container_app" "notification_service" {
  name                         = "${var.environment}-notification-service"
  container_app_environment_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.App/managedEnvironments/${var.container_apps_env_name}"
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"

  # Ingress configuration - Internal only
  ingress {
    allow_insecure_connections = false
    external_enabled           = false
    target_port                = 8085
    transport                  = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  # Registry configuration
  registry {
    server   = var.container_registry_server
    username = var.container_registry_username
    password = var.container_registry_password
  }

  # Template for container
  template {
    container {
      name   = "notification-service"
      image  = "${var.container_registry_server}/agriwizard-notification-service:${var.image_tag}"
      cpu    = var.cpu_core
      memory = "${var.memory_size}Gi"

      # Environment variables
      env {
        name  = "PORT"
        value = "8085"
      }
      env {
        name  = "DB_HOST"
        value = var.db_host
      }
      env {
        name  = "DB_PORT"
        value = var.db_port
      }
      env {
        name  = "DB_USER"
        value = var.db_user
      }
      env {
        name  = "DB_PASSWORD"
        value = var.db_password
      }
      env {
        name  = "DB_NAME"
        value = var.db_name
      }
      env {
        name  = "SERVICE_BUS_NAMESPACE"
        value = var.service_bus_namespace
      }
      env {
        name  = "SERVICE_BUS_CONNECTION"
        value = var.service_bus_connection
      }
      env {
        name  = "SMTP_HOST"
        value = "smtp.mailhog"
      }
      env {
        name  = "SMTP_PORT"
        value = "1025"
      }
      env {
        name  = "SMTP_FROM"
        value = "noreply@agriwizard.com"
      }
      env {
        name  = "GIN_MODE"
        value = "release"
      }
    }

    # Scaling rules
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    # Scale based on HTTP requests
    scale_rule {
      name = "http-scale-rule"
      custom {
        type  = "http"
        value = "10"
      }
    }
  }

  # Managed Identity
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Data source for client configuration
data "azurerm_client_config" "current" {}
