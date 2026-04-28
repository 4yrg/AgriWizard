# Azure Service Bus Namespace

resource "azurerm_service_bus_namespace" "main" {
  name                   = "${var.resource_group_name}-${var.environment}-sb"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  sku                    = var.servicebus_sku
  zone_redundant        = var.environment == "prod" ? true : false

  tags = var.tags
}

# Queue: Telemetry Ingest
resource "azurerm_service_bus_queue" "telemetry_ingest" {
  name             = "telemetry-ingest"
  namespace_id    = azurerm_service_bus_namespace.main.id
  max_message_size = 256000
  dead_lettering_on_message_expiration = true
  enable_express   = false
}

# Queue: Equipment Commands  
resource "azurerm_service_bus_queue" "equipment_commands" {
  name             = "equipment-commands"
  namespace_id    = azurerm_service_bus_namespace.main.id
  max_message_size = 256000
  dead_lettering_on_message_expiration = true
}

# Topic: Notifications
resource "azurerm_service_bus_topic" "notifications" {
  name               = "notifications"
  namespace_id      = azurerm_service_bus_namespace.main.id
  enable_express    = false
}

# Subscription: Notification Service
resource "azurerm_service_bus_subscription" "notifications_sub" {
  name             = "notifications-service"
  namespace_id    = azurerm_service_bus_namespace.main.id
  topic_name      = azurerm_service_bus_topic.notifications.name
  max_delivery_count = 10
  lock_duration    = "PT1M"
}

# Topic: Alerts
resource "azurerm_service_bus_topic" "alerts" {
  name               = "alerts"
  namespace_id      = azurerm_service_bus_namespace.main.id
  enable_express    = false
}

# Subscription: Analytics Service
resource "azurerm_service_bus_subscription" "alerts_sub" {
  name             = "analytics-service"
  namespace_id    = azurerm_service_bus_namespace.main.id
  topic_name      = azurerm_service_bus_topic.alerts.name
  max_delivery_count = 10
}