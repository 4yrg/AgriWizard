@description('Parent APIM resource name')
param apimName string

@description('Location')
param location string = resourceGroup().location

@description('JWT issuer for validation')
param jwtIssuer string = 'agriwizard-iam'

@description('JWT secret for token validation')
param jwtSecret string

@description('Backend service URLs (internal ACA URLs)')
param backendUrls object

@description('CORS allowed origins')
param allowedOrigins array = ['*']

@description('Rate limit calls per minute')
param rateLimitCalls int = 120

var apimResourceName = apimName

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimResourceName
}

resource globalPolicy 'Microsoft.ApiManagement/service/policies@2023-05-01-preview' = {
  parent: apim
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: '''
<policies>
  <inbound>
    <cors allow-credentials="true">
      <allowed-origins>
        ${join([for origin in allowedOrigins: '<origin>${origin}</origin>'], '\n        ')}
      </allowed-origins>
      <allowed-methods>
        <method>GET</method>
        <method>POST</method>
        <method>PUT</method>
        <method>DELETE</method>
        <method>PATCH</method>
        <method>OPTIONS</method>
      </allowed-methods>
      <allowed-headers>
        <header>Authorization</header>
        <header>Content-Type</header>
      </allowed-headers>
    </cors>
    <set-header name="X-Forwarded-Host" exists-action="override">
      <value>@(context.Request.Headers.GetValueOrDefault("Host",""))</value>
    </set-header>
  </inbound>
  <backend>
    <forward-request />
  </backend>
  <outbound>
  </outbound>
</policies>
'''
  }
}

resource iamApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apim
  name: 'iam-api'
  properties: {
    displayName: 'IAM Service'
    description: 'Authentication and user management service'
    path: 'api/v1/iam'
    protocols: ['https']
    subscriptionRequired: false
  }
}

resource iamApiOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: iamApi
  name: 'login'
  properties: {
    displayName: 'Login'
    method: 'POST'
    urlTemplate: '/login'
  }
}

resource iamApiOperation2 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: iamApi
  name: 'register'
  properties: {
    displayName: 'Register'
    method: 'POST'
    urlTemplate: '/register'
  }
}

resource iamApiOperation3 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: iamApi
  name: 'me'
  properties: {
    displayName: 'Get Current User'
    method: 'GET'
    urlTemplate: '/me'
  }
}

resource hardwareApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apim
  name: 'hardware-api'
  properties: {
    displayName: 'Hardware Service'
    description: 'IoT device management and MQTT control'
    path: 'api/v1/hardware'
    protocols: ['https']
    subscriptionRequired: false
  }
}

resource analyticsApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apim
  name: 'analytics-api'
  properties: {
    displayName: 'Analytics Service'
    description: 'Threshold rules and decision logic'
    path: 'api/v1/analytics'
    protocols: ['https']
    subscriptionRequired: false
  }
}

resource weatherApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apim
  name: 'weather-api'
  properties: {
    displayName: 'Weather Service'
    description: 'External weather intelligence'
    path: 'api/v1/weather'
    protocols: ['https']
    subscriptionRequired: false
  }
}

resource notificationApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apim
  name: 'notification-api'
  properties: {
    displayName: 'Notification Service'
    description: 'Email and push notifications'
    path: 'api/v1/notifications'
    protocols: ['https']
    subscriptionRequired: false
  }
}

output iamApiId string = iamApi.id
output hardwareApiId string = hardwareApi.id
output analyticsApiId string = analyticsApi.id
output weatherApiId string = weatherApi.id
output notificationApiId string = notificationApi.id