# Azure Container Registry

resource "azurerm_container_registry" "acr" {
  name                = "${replace(var.resource_group_name, "-", "")}acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"
  admin_enabled       = true

  tags = var.tags
}

# Azure Container Apps Environment

resource "azurerm_container_app_environment" "aca" {
  name                       = "${var.resource_group_name}-${var.environment}-aca"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Local helper: common DB env vars shared by most services
# ---------------------------------------------------------------------------
locals {
  db_env = {
    "DB_HOST"     = azurerm_postgresql_flexible_server.main.fqdn
    "DB_PORT"     = "5432"
    "DB_USER"      = "agriwizard"
    "DB_PASSWORD"  = "AgriWizard@${var.environment}123"
    "DB_NAME"      = "agriwizard"
  }

  service_env = {
    "KONG_HTTP_LISTEN"           = "0.0.0.0:8080"
    "KONG_DATABASE"              = "postgres"
    "KONG_PG_HOST"               = azurerm_postgresql_flexible_server.main.fqdn
    "KONG_PG_PORT"               = "5432"
    "KONG_PG_USER"               = "kong"
    "KONG_PG_PASSWORD"           = "Kong@${var.environment}123"
    "KONG_PG_DATABASE"           = "kong"
    "KONG_DECLARATIVE_CONFIG"    = "/opt/kong/kong.yml"
  }

  hivemq_env = {
    "HIVEMQ_SERVER_PORT"     = "1883"
    "HIVEMQ_WEBSOCKET_PORT"  = "8083"
    "HIVEMQ_LOG_LEVEL"       = "INFO"
  }
}

# ---------------------------------------------------------------------------
# Container App: Kong API Gateway
# ---------------------------------------------------------------------------
resource "azurerm_container_app" "kong" {
  name                         = "${var.resource_group_name}-${var.environment}-kong"
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.aca.id
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  ingress {
    target_port = 8080
    transport   = "http"
    external_enabled = true
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 1
    max_replicas = 2

    container {
      name   = "kong"
      image  = "kong:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "KONG_PROXY_ACCESS_LOG"
        value = "/dev/stdout"
      }
      env {
        name  = "KONG_ADMIN_ACCESS_LOG"
        value = "/dev/stdout"
      }
      env {
        name  = "KONG_ADMIN_LISTEN"
        value = "0.0.0.0:8001"
      }

      dynamic "env" {
        for_each = local.service_env
        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Container App: HiveMQ MQTT Broker
# ---------------------------------------------------------------------------
resource "azurerm_container_app" "hivemq" {
  name                         = "${var.resource_group_name}-${var.environment}-hivemq"
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.aca.id
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  ingress {
    target_port = 1883
    transport   = "tcp"
    external_enabled = true
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 1
    max_replicas = 2

    container {
      name   = "hivemq"
      image  = "hivemq/hivemq-ce:latest"
      cpu    = 0.5
      memory = "1Gi"

      dynamic "env" {
        for_each = local.hivemq_env
        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Container App: IAM Service
# ---------------------------------------------------------------------------
resource "azurerm_container_app" "iam" {
  name                         = "${var.resource_group_name}-${var.environment}-iam"
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.aca.id
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  ingress {
    target_port = 8086
    transport   = "http"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.iam_app_config.min_replicas
    max_replicas = var.iam_app_config.max_replicas

    container {
      name   = "iam-service"
      image  = "${azurerm_container_registry.acr.login_server}/agriwizard-iam-service:latest"
      cpu    = var.iam_app_config.cpu
      memory = "${var.iam_app_config.memory}Gi"

      env {
        name  = "PORT"
        value = "8086"
      }
      env {
        name  = "GIN_MODE"
        value = "release"
      }

      dynamic "env" {
        for_each = local.db_env
        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Container App: Hardware Service
# ---------------------------------------------------------------------------
resource "azurerm_container_app" "hardware" {
  name                         = "${var.resource_group_name}-${var.environment}-hardware"
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.aca.id
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  ingress {
    target_port = 8087
    transport   = "http"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.hardware_app_config.min_replicas
    max_replicas = var.hardware_app_config.max_replicas

    container {
      name   = "hardware-service"
      image  = "${azurerm_container_registry.acr.login_server}/agriwizard-hardware-service:latest"
      cpu    = var.hardware_app_config.cpu
      memory = "${var.hardware_app_config.memory}Gi"

      env {
        name  = "PORT"
        value = "8087"
      }

      dynamic "env" {
        for_each = local.db_env
        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Container App: Analytics Service
# ---------------------------------------------------------------------------
resource "azurerm_container_app" "analytics" {
  name                         = "${var.resource_group_name}-${var.environment}-analytics"
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.aca.id
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  ingress {
    target_port = 8088
    transport   = "http"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.analytics_app_config.min_replicas
    max_replicas = var.analytics_app_config.max_replicas

    container {
      name   = "analytics-service"
      image  = "${azurerm_container_registry.acr.login_server}/agriwizard-analytics-service:latest"
      cpu    = var.analytics_app_config.cpu
      memory = "${var.analytics_app_config.memory}Gi"

      env {
        name  = "PORT"
        value = "8088"
      }

      dynamic "env" {
        for_each = local.db_env
        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Container App: Weather Service
# ---------------------------------------------------------------------------
resource "azurerm_container_app" "weather" {
  name                         = "${var.resource_group_name}-${var.environment}-weather"
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.aca.id
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  ingress {
    target_port = 8089
    transport   = "http"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.weather_app_config.min_replicas
    max_replicas = var.weather_app_config.max_replicas

    container {
      name   = "weather-service"
      image  = "${azurerm_container_registry.acr.login_server}/agriwizard-weather-service:latest"
      cpu    = var.weather_app_config.cpu
      memory = "${var.weather_app_config.memory}Gi"

      env {
        name  = "PORT"
        value = "8089"
      }
      env {
        name  = "USE_MOCK"
        value = "true"
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Container App: Notification Service
# ---------------------------------------------------------------------------
resource "azurerm_container_app" "notification" {
  name                         = "${var.resource_group_name}-${var.environment}-notification"
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.aca.id
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  ingress {
    target_port = 8091
    transport   = "http"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.notification_app_config.min_replicas
    max_replicas = var.notification_app_config.max_replicas

    container {
      name   = "notification-service"
      image  = "${azurerm_container_registry.acr.login_server}/agriwizard-notification-service:latest"
      cpu    = var.notification_app_config.cpu
      memory = "${var.notification_app_config.memory}Gi"

      env {
        name  = "PORT"
        value = "8091"
      }

      dynamic "env" {
        for_each = local.db_env
        content {
          name  = env.key
          value = env.value
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Container App: Frontend (Next.js Web App)
# ---------------------------------------------------------------------------
resource "azurerm_container_app" "frontend" {
  name                         = "${var.resource_group_name}-${var.environment}-frontend"
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.aca.id
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  ingress {
    target_port = 3000
    transport   = "http"
    external_enabled = true
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 1
    max_replicas = 2

    container {
      name   = "frontend"
      image  = "${azurerm_container_registry.acr.login_server}/agriwizard-frontend:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "NEXT_PUBLIC_API_URL"
        value = "https://${azurerm_container_app.kong.latest_revision_fqdn}"
      }
    }
  }
}