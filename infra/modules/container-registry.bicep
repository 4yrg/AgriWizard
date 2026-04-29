// ─────────────────────────────────────────────────────────────────────────────
// Module: Azure Container Registry
// ─────────────────────────────────────────────────────────────────────────────

@description('Name of the container registry (must be globally unique, alphanumeric)')
param name string

@description('Azure region')
param location string = resourceGroup().location

@description('SKU for the container registry')
@allowed(['Basic', 'Standard', 'Premium'])
param sku string = 'Basic'

@description('Tags to apply to the resource')
param tags object = {}

// ─── Resource ────────────────────────────────────────────────────────────────

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
  }
}

// ─── Outputs ─────────────────────────────────────────────────────────────────

@description('The login server URL for the container registry')
output loginServer string = acr.properties.loginServer

@description('The resource ID of the container registry')
output id string = acr.id

@description('The name of the container registry')
output name string = acr.name

@description('The resource ID of the container registry')
output resourceId string = acr.id
