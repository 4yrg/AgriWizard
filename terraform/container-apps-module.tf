# =============================================================================
# AgriWizard - Container Apps Module Integration
# =============================================================================
# NOTE: Container Apps are deployed manually and not managed by Terraform
# to avoid import issues with existing manually-deployed container apps

# module "container_apps" {
#   source = "./modules/container-apps"

#   # Resource configuration
#   resource_group_name     = data.azurerm_resource_group.main.name
#   location                = data.azurerm_resource_group.main.location
#   container_apps_env_name = azurerm_container_app_environment.main.name

#   # Container Registry
#   container_registry_server   = azurerm_container_registry.main.login_server
#   container_registry_username = azurerm_container_registry.main.admin_username
#   container_registry_password = azurerm_container_registry.main.admin_password

#   # Image configuration
#   image_tag = var.image_tag

#   # Database configuration - Using external database placeholder
#   db_host     = "postgres"
#   db_port     = 5432
#   db_name     = "agriwizard"
#   db_user     = var.postgresql_admin_username
#   db_password = var.postgresql_admin_password

#   # JWT Secret
#   jwt_secret = var.jwt_secret

#   # IoT Hub configuration (commented out - not deployed)
#   iot_hub_name = ""

#   # Service Bus configuration
#   service_bus_namespace  = azurerm_servicebus_namespace.main.name
#   service_bus_connection = azurerm_servicebus_namespace_authorization_rule.container_apps.primary_connection_string

#   # Environment
#   environment = var.environment

#   # Scaling configuration
#   cpu_core     = var.cpu_core
#   memory_size  = var.memory_size
#   min_replicas = var.min_replicas
#   max_replicas = var.max_replicas

#   # Tags
#   tags = local.common_tags

#   depends_on = [
#     azurerm_container_registry.main,
#     azurerm_container_app_environment.main,
#     azurerm_servicebus_namespace.main
#   ]
# }

# =============================================================================
# API Management - Backend Services (commented out - using Kong instead)
# =============================================================================

# resource "azurerm_api_management_backend" "iam_service" {
#   name                = "iam-service-backend"
#   resource_group_name = data.azurerm_resource_group.main.name
#   api_management_name = azurerm_api_management.main.name
#   protocol            = "http"
#
#   url   = "http://${module.container_apps.iam_service_url}"
#   title = "IAM Service"
# }

# resource "azurerm_api_management_backend" "hardware_service" {
#   name                = "hardware-service-backend"
#   resource_group_name = data.azurerm_resource_group.main.name
#   api_management_name = azurerm_api_management.main.name
#   protocol            = "http"
#
#   url   = "http://${module.container_apps.hardware_service_url}"
#   title = "Hardware Service"
# }

# resource "azurerm_api_management_backend" "analytics_service" {
#   name                = "analytics-service-backend"
#   resource_group_name = data.azurerm_resource_group.main.name
#   api_management_name = azurerm_api_management.main.name
#   protocol            = "http"
#
#   url   = "http://${module.container_apps.analytics_service_url}"
#   title = "Analytics Service"
# }

# resource "azurerm_api_management_backend" "weather_service" {
#   name                = "weather-service-backend"
#   resource_group_name = data.azurerm_resource_group.main.name
#   api_management_name = azurerm_api_management.main.name
#   protocol            = "http"
#
#   url   = "http://${module.container_apps.weather_service_url}"
#   title = "Weather Service"
# }

# resource "azurerm_api_management_backend" "notification_service" {
#   name                = "notification-service-backend"
#   resource_group_name = data.azurerm_resource_group.main.name
#   api_management_name = azurerm_api_management.main.name
#   protocol            = "http"
#
#   url   = "http://${module.container_apps.notification_service_url}"
#   title = "Notification Service"
# }

# =============================================================================
# API Management - API Operations (commented out)
# =============================================================================

# resource "azurerm_api_management_api_operation" "iam_operations" {
#   operation_id        = "iam-operations"
#   api_name            = azurerm_api_management_api.agriwizard.name
#   api_management_name = azurerm_api_management.main.name
#   resource_group_name = data.azurerm_resource_group.main.name
#   display_name        = "IAM Operations"
#   method              = "ANY"
#   url_template        = "/iam/*"
# }

# resource "azurerm_api_management_api_operation" "hardware_operations" {
#   operation_id        = "hardware-operations"
#   api_name            = azurerm_api_management_api.agriwizard.name
#   api_management_name = azurerm_api_management.main.name
#   resource_group_name = data.azurerm_resource_group.main.name
#   display_name        = "Hardware Operations"
#   method              = "ANY"
#   url_template        = "/hardware/*"
# }

# resource "azurerm_api_management_api_operation" "analytics_operations" {
#   operation_id        = "analytics-operations"
#   api_name            = azurerm_api_management_api.agriwizard.name
#   api_management_name = azurerm_api_management.main.name
#   resource_group_name = data.azurerm_resource_group.main.name
#   display_name        = "Analytics Operations"
#   method              = "ANY"
#   url_template        = "/analytics/*"
# }

# resource "azurerm_api_management_api_operation" "weather_operations" {
#   operation_id        = "weather-operations"
#   api_name            = azurerm_api_management_api.agriwizard.name
#   api_management_name = azurerm_api_management.main.name
#   resource_group_name = data.azurerm_resource_group.main.name
#   display_name        = "Weather Operations"
#   method              = "ANY"
#   url_template        = "/weather/*"
# }

# resource "azurerm_api_management_api_operation" "notification_operations" {
#   operation_id        = "notification-operations"
#   api_name            = azurerm_api_management_api.agriwizard.name
#   api_management_name = azurerm_api_management.main.name
#   resource_group_name = data.azurerm_resource_group.main.name
#   display_name        = "Notification Operations"
#   method              = "ANY"
#   url_template        = "/notifications/*"
# }

# resource "azurerm_api_management_api_operation" "template_operations" {
#   operation_id        = "template-operations"
#   api_name            = azurerm_api_management_api.agriwizard.name
#   api_management_name = azurerm_api_management.main.name
#   resource_group_name = data.azurerm_resource_group.main.name
#   display_name        = "Template Operations"
#   method              = "ANY"
#   url_template        = "/templates/*"
# }

# =============================================================================
# Key Vault Secrets
# =============================================================================

resource "azurerm_key_vault_secret" "db_password" {
  name         = "database-password"
  value        = var.postgresql_admin_password
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current_user]
}

resource "azurerm_key_vault_secret" "jwt_secret" {
  name         = "jwt-secret"
  value        = var.jwt_secret
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current_user]
}

# resource "azurerm_key_vault_secret" "iot_hub_connection" {
#   name  = "iot-hub-connection-string"
#   value = "HostName=${var.iot_hub_name}.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=<replace-with-actual-key>"
#
#   key_vault_id = azurerm_key_vault.main.id
#
#   depends_on = [azurerm_key_vault_access_policy.current_user]
# }

resource "azurerm_key_vault_secret" "service_bus_connection" {
  name         = "service-bus-connection-string"
  value        = azurerm_servicebus_namespace_authorization_rule.container_apps.primary_connection_string
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current_user]
}

# =============================================================================
# API Management - Policies (commented out - using Kong instead)
# =============================================================================

# JWT Validation Policy - Uncomment after services are deployed
# resource "azurerm_api_management_policy" "jwt_validation" {
#   api_management_id = azurerm_api_management.main.id
#   xml_content       = <<XML
# <policies>
#     <inbound>
#         <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized. Invalid or expired token.">
#             <openid-config url="https://login.microsoftonline.com/{tenant}/.well-known/openid-configuration" />
#             <audiences>
#                 <audience>agriwizard-api</audience>
#             </audiences>
#             <issuers>
#                 <issuer>agriwizard-iam-service</issuer>
#             </issuers>
#         </validate-jwt>
#         <rate-limit-by-key calls="100" renewal-period="60" counter-key="@(context.Request.IpAddress)" />
#     </inbound>
#     <backend>
#         <forward-request />
#     </backend>
#     <outbound>
#         <base />
#     </outbound>
#     <on-error>
#         <base />
#     </on-error>
# </policies>
# XML
# }
