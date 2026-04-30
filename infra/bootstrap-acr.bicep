targetScope = 'subscription'

@description('Name prefix for all resources.')
param namePrefix string

@description('Deployment location.')
param location string = deployment().location

@description('Short environment suffix.')
param environmentSuffix string = 'prod'

@description('The name of the ACR.')
param acrName string

var resourceGroupName = '${namePrefix}-${environmentSuffix}-rg'
var identityName = '${namePrefix}-${environmentSuffix}-aca-mi'
var uniqueSuffix = uniqueString(subscription().id, resourceGroupName)
var computedAcrName = empty(acrName) ? take('${namePrefix}acr${uniqueSuffix}', 50) : acrName

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
    serviceBusName: take('${namePrefix}-${environmentSuffix}-sb-${uniqueSuffix}', 50)
  }
  dependsOn: [
    rg
  ]
}

output resourceGroupName string = resourceGroupName
output acrName string = acr.outputs.acrNameOut
output acrLoginServer string = acr.outputs.acrLoginServer
output serviceBusConnection string = servicebus.outputs.connectionString
