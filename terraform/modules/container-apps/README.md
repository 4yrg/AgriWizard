# Container Apps Module - AgriWizard Microservices

This module deploys all AgriWizard microservices to Azure Container Apps.

## Services Deployed

1. **IAM Service** (port 8081) - External ingress via API Gateway
2. **Hardware Service** (port 8082) - Internal ingress
3. **Analytics Service** (port 8083) - Internal ingress
4. **Weather Service** (port 8084) - Internal ingress

## Usage

```hcl
module "container_apps" {
  source = "./modules/container-apps"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  container_apps_env_name    = azurerm_container_app_environment.main.name
  container_registry_server  = azurerm_container_registry.main.login_server
  container_registry_username = azurerm_container_registry.main.admin_username
  container_registry_password = azurerm_container_registry.main.admin_password
  
  image_tag = "latest"
  
  # Service URLs for inter-service communication
  iam_service_url       = module.container_apps.iam_service_url
  hardware_service_url  = module.container_apps.hardware_service_url
  analytics_service_url = module.container_apps.analytics_service_url
  weather_service_url   = module.container_apps.weather_service_url
  
  # Database configuration
  db_host     = azurerm_postgresql_flexible_server.main.fqdn
  db_port     = "5432"
  db_name     = "agriwizard"
  db_user     = var.postgresql_admin_username
  db_password = var.postgresql_admin_password
  
  # JWT Secret from Key Vault
  jwt_secret = var.jwt_secret
  
  # IoT Hub configuration
  iot_hub_name = azurerm_iothub.main.name
  
  environment = var.environment
  tags        = local.common_tags
}
```
