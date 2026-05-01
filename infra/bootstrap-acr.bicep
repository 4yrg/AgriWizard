targetScope = 'subscription'

@description('Name prefix for all resources.')
param namePrefix string

@description('Deployment location.')
param location string = deployment().location

@description('Short environment suffix.')
param environmentSuffix string = 'prod'

@description('The name of the ACR.')
param acrName string = ''

@description('APIM publisher email.')
param publisherEmail string = 'devops@agriwizard.io'

@description('JWT issuer for API authentication.')
param jwtIssuer string = 'agriwizard-iam'

@description('Allowed CORS origins.')
param allowedOrigins array = ['*']

var resourceGroupName = '${namePrefix}-${environmentSuffix}-rg'
var identityName = '${namePrefix}-${environmentSuffix}-aca-mi'
var uniqueSuffix = uniqueString(subscription().id, resourceGroupName)
var computedAcrName = empty(acrName) ? take('${namePrefix}acr${uniqueSuffix}', 50) : acrName
var apimNameBase = take('${namePrefix}-${environmentSuffix}-apim', 24)

module rg './modules/resource-group.bicep' = {
  name: 'resource-group-bootstrap'
  params: {
    location: location
    resourceGroupName: resourceGroupName
  }
}

module identity './modules/identity.bicep' = {
  name: 'identity-bootstrap'
  scope: resourceGroup(resourceGroupName)
  params: {
    identityName: identityName
  }
}

module acr './modules/acr.bicep' = {
  name: 'acr-bootstrap'
  scope: resourceGroup(resourceGroupName)
  params: {
    acrName: computedAcrName
    sku: 'Standard'
    pullPrincipalId: identity.outputs.principalId
  }
}

module servicebus './modules/servicebus.bicep' = {
  name: 'servicebus-bootstrap'
  scope: resourceGroup(resourceGroupName)
  params: {
    serviceBusName: take('${namePrefix}sb${uniqueSuffix}', 50)
  }
  dependsOn: [
    rg
  ]
}

module apim './modules/apim.bicep' = {
  name: 'apim-bootstrap'
  scope: resourceGroup(resourceGroupName)
  params: {
    apimNameBase: apimNameBase
    location: location
    publisherEmail: publisherEmail
    jwtIssuer: jwtIssuer
    allowedOrigins: allowedOrigins
    backendServices: []
  }
  dependsOn: [
    rg
  ]
}

output resourceGroupName string = resourceGroupName
output acrName string = acr.outputs.acrNameOut
output acrLoginServer string = acr.outputs.acrLoginServer
output serviceBusConnectionString string = servicebus.outputs.connectionString
output apimName string = apim.outputs.apimName
output apimGatewayUrl string = apim.outputs.apimGatewayUrl
