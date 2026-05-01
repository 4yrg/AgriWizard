@description('API Management - Consumption tier')
@allowed(['Consumption'])
param apimSkuName string = 'Consumption'

@description('API Management service name base.')
param apimNameBase string = 'agriwizard'

@description('Location for the APIM instance.')
param location string = resourceGroup().location

@description('Publisher email for SSL certificates and notifications.')
param publisherEmail string = '4yrg.main@gmail.com'

@description('Publisher name.')
param publisherName string = 'AgriWizard Admin'

@description('JWT issuer for API authentication.')
param jwtIssuer string = 'agriwizard-iam'

@description('Allowed CORS origins.')
param allowedOrigins array = ['*']

@description('JWT secret for token validation.')
@secure()
param jwtSecret string = ''

@description('List of backend services with their internal URLs.')
param backendServices array = []

var uniqueSuffix = uniqueString(resourceGroup().id)
var apimResourceName = '${apimNameBase}-${uniqueSuffix}'

var backendUrlsMap = {
  iam: 'iam-prod.agriwizard-prod-rg.centralindia.azurecontainerapps.io'
  hardware: 'hardware-prod.agriwizard-prod-rg.centralindia.azurecontainerapps.io'
  analytics: 'analytics-prod.agriwizard-prod-rg.centralindia.azurecontainerapps.io'
  weather: 'weather-prod.agriwizard-prod-rg.centralindia.azurecontainerapps.io'
  notification: 'notification-prod.agriwizard-prod-rg.centralindia.azurecontainerapps.io'
}

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apimResourceName
  location: location
  sku: {
    name: apimSkuName
    capacity: 0
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

module apimApi './apim-api.bicep' = {
  name: 'apim-api-config'
  params: {
    apimName: apimResourceName
    location: location
    jwtIssuer: jwtIssuer
    jwtSecret: !empty(jwtSecret) ? jwtSecret : 'temp'
    backendUrls: backendUrlsMap
    allowedOrigins: allowedOrigins
  }
  dependsOn: [
    apim
  ]
}

output apimName string = apim.name
output apimResourceId string = apim.id
output apimPortalUrl string = apim.properties.portalUrl
output apimGatewayUrl string = apim.properties.gatewayUrl
output apimGatewayHostName string = apim.properties.gatewayUrl
output managedIdentityPrincipalId string = apim.identity.principalId
output apimNameBase string = apimNameBase