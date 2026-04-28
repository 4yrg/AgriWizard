# Azure API Management

resource "azurerm_api_management" "main" {
  name                = "${var.resource_group_name}-${var.environment}-apim"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  publisher_name     = var.apim_publisher_name
  publisher_email    = "team@agriwizard.com"
  sku_name           = var.apim_sku
  virtual_network_type = "Internal"
  

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# API Management Backend (pointing to Container Apps)
resource "azurerm_api_management_backend" "iam" {
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  name                = "iam-backend"
  protocol           = "http"
  url                = "http://${azurerm_container_app.iam.fqdn}"

  credentials {
    header = {
      Authorization = "SharedAccessSignature {{masterKey}}"
    }
  }

  proxy {
    url = "http://${azurerm_container_app.iam.fqdn}"
  }
}

# API: IAM
resource "azurerm_api_management_api" "iam" {
  name                = "iam-api"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "IAM Service"
  description        = "Identity and Access Management"
  revision           = "1"
  service_url        = "/api/v1/iam"
  protocol           = ["https"]

  import_api {
    content_format = "openapi"
    content_value = file("${path.module}/../../swagger.yaml")
  }

  # Operation: Login
  operation {
    name = "login"
    method = "POST"
    url_template = "/auth/login"
    display_name = "Login"
    description = "Authenticate user and get JWT token"
  }

  # Operation: Register  
  operation {
    name = "register"
    method = "POST"
    url_template = "/auth/register"
    display_name = "Register"
    description = "Register new user"
  }
}

# Rate limiting policy
resource "azurerm_api_management_policy" "main" {
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name

  xml = <<XML
<policies>
  <inbound>
    <base />
    <validate-jwt header-name="Authorization">
      <openid-config url="https://${azurerm_api_management.main.name}.managedidentities.azure.com/.well-known/openid-configuration" />
      <audiences>
        <audience>agriwizard-iam</audience>
      </audiences>
      <issuers>
        <issuer>agriwizard-iam</issuer>
      </issuers>
    </validate-jwt>
    <rate-limit-by-key calls="120" renewal-period="60" counter-key="@(context.Request.IpAddress)" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}