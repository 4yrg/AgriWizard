# Azure Service Bus Namespace

resource "azurerm_servicebus_namespace" "main" {
  name                = "${var.resource_group_name}-${var.environment}-sbns"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.servicebus_sku

  tags = var.tags
}

# Queue: Telemetry Ingest
resource "azurerm_servicebus_queue" "telemetry_ingest" {
  name         = "telemetry-ingest"
  namespace_id = azurerm_servicebus_namespace.main.id
  dead_lettering_on_message_expiration = true
}

# Queue: Equipment Commands
resource "azurerm_servicebus_queue" "equipment_commands" {
  name         = "equipment-commands"
  namespace_id = azurerm_servicebus_namespace.main.id
  dead_lettering_on_message_expiration = true
}

# Topic: Notifications
# express_enabled replaces deprecated enable_express
resource "azurerm_servicebus_topic" "notifications" {
  name            = "notifications"
  namespace_id    = azurerm_servicebus_namespace.main.id
  express_enabled = false
}

# Topic: Alerts
resource "azurerm_servicebus_topic" "alerts" {
  name            = "alerts"
  namespace_id    = azurerm_servicebus_namespace.main.id
  express_enabled = false
}

# Subscription: Notification Service
# topic_id replaces legacy namespace_id + topic_name pattern
resource "azurerm_servicebus_subscription" "notifications_sub" {
  name               = "notifications-service"
  topic_id           = azurerm_servicebus_topic.notifications.id
  max_delivery_count = 10
  lock_duration      = "PT1M"
}

# Subscription: Analytics Service
resource "azurerm_servicebus_subscription" "alerts_sub" {
  name               = "analytics-service"
  topic_id           = azurerm_servicebus_topic.alerts.id
  max_delivery_count = 10
}
