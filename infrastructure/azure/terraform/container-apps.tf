# Azure Container Registry

resource "azurerm_container_registry" "acr" {
  name                   = "${replace(var.resource_group_name, "-", "")}${var.environment}acr"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  sku                    = "Standard"
  admin_enabled         = true

  tags = var.tags
}

# Azure Container Apps Environment

resource "azurerm_container_app_environment" "aca" {
  name                = "${var.resource_group_name}-${var.environment}-aca"
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location

  log_analytics {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  tags = var.tags
}

# Container App: IAM Service
resource "azurerm_container_app" "iam" {
  name                  = "${var.resource_group_name}-${var.environment}-iam"
  resource_group_name  = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  container_app_environment_id = azurerm_container_app_environment.aca.id
  revision_mode        = "Single"

  ingress {
    target_port      = 8086
    transport       = "http"
    allow_insecure = false
  }

  container {
    name   = "iam-service"
    image = "${azurerm_container_registry.acr.login_server}/agriwizard-iam-service:latest"

    cpu    = var.iam_app_config.cpu
    memory = var.iam_app_config.memory

    environment_variables = {
      PORT        = "8086"
      DB_HOST    = azurerm_postgresql_flexible_server.main.fqdn
      DB_PORT    = "5432"
      DB_USER    = "agriwizard"
      DB_PASSWORD = "AgriWizard@${var.environment}123"
      DB_NAME    = "agriwizard"
      GIN_MODE  = "release"
    }
  }

  scaling {
    min_replicas = var.iam_app_config.min_replicas
    max_replicas = var.iam_app_config.max_replicas
  }
}

# Container App: Hardware Service
resource "azurerm_container_app" "hardware" {
  name                  = "${var.resource_group_name}-${var.environment}-hardware"
  resource_group_name  = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  container_app_environment_id = azurerm_container_app_environment.aca.id
  revision_mode        = "Single"

  ingress {
    target_port      = 8087
    transport       = "http"
    allow_insecure = false
  }

  container {
    name   = "hardware-service"
    image = "${azurerm_container_registry.acr.login_server}/agriwizard-hardware-service:latest"

    cpu    = var.hardware_app_config.cpu
    memory = var.hardware_app_config.memory

    environment_variables = {
      PORT        = "8087"
      DB_HOST    = azurerm_postgresql_flexible_server.main.fqdn
      DB_PORT    = "5432"
      DB_USER    = "agriwizard"
      DB_PASSWORD = "AgriWizard@${var.environment}123"
      DB_NAME    = "agriwizard"
    }
  }

  scaling {
    min_replicas = var.hardware_app_config.min_replicas
    max_replicas = var.hardware_app_config.max_replicas
  }
}

# Container App: Analytics Service
resource "azurerm_container_app" "analytics" {
  name                  = "${var.resource_group_name}-${var.environment}-analytics"
  resource_group_name  = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  container_app_environment_id = azurerm_container_app_environment.aca.id
  revision_mode        = "Single"

  ingress {
    target_port      = 8088
    transport       = "http"
    allow_insecure = false
  }

  container {
    name   = "analytics-service"
    image = "${azurerm_container_registry.acr.login_server}/agriwizard-analytics-service:latest"

    cpu    = var.analytics_app_config.cpu
    memory = var.analytics_app_config.memory

    environment_variables = {
      PORT        = "8088"
      DB_HOST    = azurerm_postgresql_flexible_server.main.fqdn
      DB_PORT    = "5432"
      DB_USER    = "agriwizard"
      DB_PASSWORD = "AgriWizard@${var.environment}123"
      DB_NAME    = "agriwizard"
    }
  }

  scaling {
    min_replicas = var.analytics_app_config.min_replicas
    max_replicas = var.analytics_app_config.max_replicas
  }
}

# Container App: Weather Service
resource "azurerm_container_app" "weather" {
  name                  = "${var.resource_group_name}-${var.environment}-weather"
  resource_group_name  = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  container_app_environment_id = azurerm_container_app_environment.aca.id
  revision_mode        = "Single"

  ingress {
    target_port      = 8089
    transport       = "http"
    allow_insecure = false
  }

  container {
    name   = "weather-service"
    image = "${azurerm_container_registry.acr.login_server}/agriwizard-weather-service:latest"

    cpu    = var.weather_app_config.cpu
    memory = var.weather_app_config.memory

    environment_variables = {
      PORT        = "8089"
      USE_MOCK    = "true"
    }
  }

  scaling {
    min_replicas = var.weather_app_config.min_replicas
    max_replicas = var.weather_app_config.max_replicas
  }
}

# Container App: Notification Service
resource "azurerm_container_app" "notification" {
  name                  = "${var.resource_group_name}-${var.environment}-notification"
  resource_group_name  = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  container_app_environment_id = azurerm_container_app_environment.aca.id
  revision_mode        = "Single"

  ingress {
    target_port      = 8091
    transport       = "http"
    allow_insecure = false
  }

  container {
    name   = "notification-service"
    image = "${azurerm_container_registry.acr.login_server}/agriwizard-notification-service:latest"

    cpu    = var.notification_app_config.cpu
    memory = var.notification_app_config.memory

    environment_variables = {
      PORT        = "8091"
      DB_HOST    = azurerm_postgresql_flexible_server.main.fqdn
      DB_PORT    = "5432"
      DB_USER    = "agriwizard"
      DB_PASSWORD = "AgriWizard@${var.environment}123"
      DB_NAME    = "agriwizard"
    }
  }

  scaling {
    min_replicas = var.notification_app_config.min_replicas
    max_replicas = var.notification_app_config.max_replicas
  }
}