targetScope = 'subscription'

@description('Azure region for the resource group.')
param location string

@description('Resource group name.')
param resourceGroupName string

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

output name string = rg.name
output id string = rg.id
