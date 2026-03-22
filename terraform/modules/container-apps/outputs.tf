output "iam_service_name" {
  description = "IAM Service Container App name"
  value       = azurerm_container_app.iam_service.name
}

output "iam_service_url" {
  description = "IAM Service FQDN"
  value       = azurerm_container_app.iam_service.latest_revision_fqdn
}

output "hardware_service_name" {
  description = "Hardware Service Container App name"
  value       = azurerm_container_app.hardware_service.name
}

output "hardware_service_url" {
  description = "Hardware Service FQDN"
  value       = azurerm_container_app.hardware_service.latest_revision_fqdn
}

output "analytics_service_name" {
  description = "Analytics Service Container App name"
  value       = azurerm_container_app.analytics_service.name
}

output "analytics_service_url" {
  description = "Analytics Service FQDN"
  value       = azurerm_container_app.analytics_service.latest_revision_fqdn
}

output "weather_service_name" {
  description = "Weather Service Container App name"
  value       = azurerm_container_app.weather_service.name
}

output "weather_service_url" {
  description = "Weather Service FQDN"
  value       = azurerm_container_app.weather_service.latest_revision_fqdn
}

output "all_service_urls" {
  description = "All service URLs for reference"
  value = {
    iam       = azurerm_container_app.iam_service.latest_revision_fqdn
    hardware  = azurerm_container_app.hardware_service.latest_revision_fqdn
    analytics = azurerm_container_app.analytics_service.latest_revision_fqdn
    weather   = azurerm_container_app.weather_service.latest_revision_fqdn
  }
}
