// ─────────────────────────────────────────────────────────────────────────────
// Module: Azure API Management (Consumption Tier)
// ─────────────────────────────────────────────────────────────────────────────

@description('Name of the API Management instance')
param name string

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Tags to apply to the resource')
param tags object = {}

@description('Email address of the publisher')
param publisherEmail string = 'admin@agriwizard.local'

@description('Name of the publisher')
param publisherName string = 'AgriWizard'

@secure()
@description('JWT Secret used for validation')
param jwtSecret string

@description('FQDN of the IAM service')
param iamFqdn string

@description('FQDN of the Hardware service')
param hardwareFqdn string

@description('FQDN of the Analytics service')
param analyticsFqdn string

@description('FQDN of the Weather service')
param weatherFqdn string

@description('FQDN of the Notification service')
param notificationFqdn string

// ─── Resource ────────────────────────────────────────────────────────────────

resource apim 'Microsoft.ApiManagement/service@2022-08-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Developer'
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

// Named Value for JWT Secret
resource jwtSecretValue 'Microsoft.ApiManagement/service/namedValues@2022-08-01' = {
  parent: apim
  name: 'jwt-secret'
  properties: {
    displayName: 'jwt-secret'
    secret: true
    value: jwtSecret
  }
}

// Global Policy (CORS)
resource globalPolicy 'Microsoft.ApiManagement/service/policies@2022-08-01' = {
  parent: apim
  name: 'policy'
  properties: {
    format: 'xml'
    value: '<policies>\r\n  <inbound>\r\n    <cors allow-credentials="true">\r\n      <allowed-origins>\r\n        <origin>*</origin>\r\n      </allowed-origins>\r\n      <allowed-methods>\r\n        <method>GET</method>\r\n        <method>POST</method>\r\n        <method>PUT</method>\r\n        <method>DELETE</method>\r\n        <method>PATCH</method>\r\n        <method>OPTIONS</method>\r\n      </allowed-methods>\r\n      <allowed-headers>\r\n        <header>Authorization</header>\r\n        <header>Content-Type</header>\r\n        <header>X-Request-ID</header>\r\n        <header>X-Internal-Service</header>\r\n      </allowed-headers>\r\n      <expose-headers>\r\n        <header>X-Kong-Upstream-Latency</header>\r\n        <header>X-Kong-Proxy-Latency</header>\r\n      </expose-headers>\r\n    </cors>\r\n  </inbound>\r\n  <backend>\r\n    <forward-request />\r\n  </backend>\r\n  <outbound />\r\n  <on-error />\r\n</policies>'
  }
}

var apis = [
  { name: 'iam-legacy', path: 'api/v1/iam', fqdn: iamFqdn, backendPath: '/api/v1/iam', requireJwt: false }
  { name: 'auth', path: 'auth', fqdn: iamFqdn, backendPath: '/api/v1/iam', requireJwt: false }
  { name: 'hardware-legacy', path: 'api/v1/hardware', fqdn: hardwareFqdn, backendPath: '/api/v1/hardware', requireJwt: true }
  { name: 'hardware', path: 'hardware', fqdn: hardwareFqdn, backendPath: '/api/v1/hardware', requireJwt: true }
  { name: 'analytics-legacy', path: 'api/v1/analytics', fqdn: analyticsFqdn, backendPath: '/api/v1/analytics', requireJwt: true }
  { name: 'analytics', path: 'analytics', fqdn: analyticsFqdn, backendPath: '/api/v1/analytics', requireJwt: true }
  { name: 'weather-legacy', path: 'api/v1/weather', fqdn: weatherFqdn, backendPath: '/api/v1/weather', requireJwt: true }
  { name: 'weather', path: 'weather', fqdn: weatherFqdn, backendPath: '/api/v1/weather', requireJwt: true }
  { name: 'notification-legacy', path: 'api/v1/notifications', fqdn: notificationFqdn, backendPath: '/api/v1/notifications', requireJwt: true }
  { name: 'notifications', path: 'notifications', fqdn: notificationFqdn, backendPath: '/api/v1/notifications', requireJwt: true }
  { name: 'templates-legacy', path: 'api/v1/templates', fqdn: notificationFqdn, backendPath: '/api/v1/templates', requireJwt: true }
  { name: 'templates', path: 'templates', fqdn: notificationFqdn, backendPath: '/api/v1/templates', requireJwt: true }
]

resource apiDefs 'Microsoft.ApiManagement/service/apis@2022-08-01' = [for api in apis: {
  parent: apim
  name: api.name
  properties: {
    displayName: api.name
    path: api.path
    protocols: ['https']
    serviceUrl: 'https://${api.fqdn}${api.backendPath}'
    subscriptionRequired: false
  }
}]

resource apiOperationsAll 'Microsoft.ApiManagement/service/apis/operations@2022-08-01' = [for (api, i) in apis: {
  parent: apiDefs[i]
  name: 'all-operations'
  properties: {
    displayName: 'All Operations'
    method: '*'
    urlTemplate: '/*'
  }
}]

resource apiOperationsRoot 'Microsoft.ApiManagement/service/apis/operations@2022-08-01' = [for (api, i) in apis: {
  parent: apiDefs[i]
  name: 'root-operation'
  properties: {
    displayName: 'Root Operation'
    method: '*'
    urlTemplate: '/'
  }
}]

resource apiPolicies 'Microsoft.ApiManagement/service/apis/policies@2022-08-01' = [for (api, i) in apis: if (api.requireJwt) {
  parent: apiDefs[i]
  name: 'policy'
  properties: {
    format: 'xml'
    value: '<policies>\r\n  <inbound>\r\n    <base />\r\n    <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized" require-expiration-time="true" require-scheme="Bearer" require-signed-tokens="true">\r\n      <issuer-signing-keys>\r\n        <key>{{jwt-secret}}</key>\r\n      </issuer-signing-keys>\r\n    </validate-jwt>\r\n  </inbound>\r\n  <backend>\r\n    <base />\r\n  </backend>\r\n  <outbound>\r\n    <base />\r\n  </outbound>\r\n  <on-error>\r\n    <base />\r\n  </on-error>\r\n</policies>'
  }
}]

// ─── Outputs ─────────────────────────────────────────────────────────────────

@description('The APIM Gateway URL')
output gatewayUrl string = apim.properties.gatewayUrl
