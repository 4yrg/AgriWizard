# Azure IoT Hub

resource "azurerm_iothub" "main" {
  name                = "${var.resource_group_name}-${var.environment}-iothub"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku_name            = var.iothub_sku
  units              = var.iothub_units

  # Enable built-in endpoints
  endpoint {
    name                 = "events"
    event_hub_namespace_name = azurerm_iothub.main.name
    event_hub_name     = "events"
    partition_count   = 2
    retention          = 1
  }

  # Fallback route
  route {
    name           = "default"
    source         = "DeviceConnectionState"
    endpoint_name  = "events"
    condition      = "true"
    enabled        = true
  }

  tags = var.tags
}

# IOT Hub Consumer Group
resource "azurerm_iothub_consumer_group" "main" {
  name           = "agriwizard-analytics"
  iothub_name   = azurerm_iothub.main.name
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_iothub_consumer_group" "notification" {
  name           = "agriwizard-notification"
  iothub_name   = azurerm_iothub.main.name
  resource_group_name = azurerm_resource_group.main.name
}

# IoT Hub Shared Access Policy for Container Apps
resource "azurerm_iothub_shared_access_policy" "container_apps" {
  name           = "container-apps"
  iothub_name   = azurerm_iothub.main.name
  resource_group_name = azurerm_resource_group.main.name

  service_connect     = true
  device_connect     = true
  registry_read      = true
  registry_write    = true
}