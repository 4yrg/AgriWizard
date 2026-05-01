@description('API Management - Consumption tier')
@allowed(['Consumption'])
param apimSkuName string = 'Consumption'

@description('API Management service name.')
param apimName string

@description('Location for the APIM instance.')
param location string = resourceGroup().location

@description('Publisher email for SSL certificates and notifications.')
param publisherEmail string

@description('Publisher name.')
param publisherName string = 'AgriWizard Platform'

@description('List of backend services with their internal URLs.')
param backendServices array = []

var apimResourceName = apimName

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

output apimName string = apim.name
output apimResourceId string = apim.id
output apimPortalUrl string = apim.properties.portalUrl
output apimGatewayUrl string = apim.properties.gatewayUrl
output apimGatewayHostName string = apim.properties.gatewayUrl
output managedIdentityPrincipalId string = apim.identity.principalId