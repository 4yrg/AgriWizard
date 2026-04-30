targetScope = 'resourceGroup'

@description('Azure Container Registry name.')
param acrName string

@description('ACR SKU.')
param sku string = 'Standard'

@description('Principal ID of the managed identity that should pull images.')
param pullPrincipalId string

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: resourceGroup().location
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: false
  }
}

resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, pullPrincipalId, 'AcrPull')
  scope: acr
  properties: {
    principalId: pullPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    )
  }
}

output acrId string = acr.id
output acrNameOut string = acr.name
output acrLoginServer string = acr.properties.loginServer
