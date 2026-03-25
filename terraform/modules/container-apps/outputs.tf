output "iam_service_name" {
  description = "IAM Service Container App name"
  value       = azurerm_container_app.iam_service.name
}

output "iam_service_url" {
  description = "IAM Service FQDN"
  value       = try(azurerm_container_app.iam_service.latest_revision_fqdn, null)
}

output "hardware_service_name" {
  description = "Hardware Service Container App name"
  value       = azurerm_container_app.hardware_service.name
}

output "hardware_service_url" {
  description = "Hardware Service FQDN"
  value       = try(azurerm_container_app.hardware_service.latest_revision_fqdn, null)
}

output "analytics_service_name" {
  description = "Analytics Service Container App name"
  value       = azurerm_container_app.analytics_service.name
}

output "analytics_service_url" {
  description = "Analytics Service FQDN"
  value       = try(azurerm_container_app.analytics_service.latest_revision_fqdn, null)
}

output "weather_service_name" {
  description = "Weather Service Container App name"
  value       = azurerm_container_app.weather_service.name
}

output "weather_service_url" {
  description = "Weather Service FQDN"
  value       = try(azurerm_container_app.weather_service.latest_revision_fqdn, null)
}

output "notification_service_name" {
  description = "Notification Service Container App name"
  value       = azurerm_container_app.notification_service.name
}

output "notification_service_url" {
  description = "Notification Service FQDN"
  value       = try(azurerm_container_app.notification_service.latest_revision_fqdn, null)
}

output "all_service_urls" {
  description = "All service URLs for reference"
  value = {
    iam          = try(azurerm_container_app.iam_service.latest_revision_fqdn, null)
    hardware     = try(azurerm_container_app.hardware_service.latest_revision_fqdn, null)
    analytics    = try(azurerm_container_app.analytics_service.latest_revision_fqdn, null)
    weather      = try(azurerm_container_app.weather_service.latest_revision_fqdn, null)
    notification = try(azurerm_container_app.notification_service.latest_revision_fqdn, null)
  }
}
