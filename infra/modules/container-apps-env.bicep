// ─────────────────────────────────────────────────────────────────────────────
// Module: Azure Container Apps Environment
// ─────────────────────────────────────────────────────────────────────────────

@description('Name of the Container Apps environment')
param name string

@description('Azure region')
param location string = resourceGroup().location

@description('Tags to apply to the resource')
param tags object = {}

@description('Log Analytics workspace customer ID')
param logAnalyticsCustomerId string

@secure()
@description('Log Analytics workspace shared key')
param logAnalyticsSharedKey string

// ─── Resource ────────────────────────────────────────────────────────────────

resource containerAppsEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsCustomerId
        sharedKey: logAnalyticsSharedKey
      }
    }
    zoneRedundant: false
  }
}

// ─── Outputs ─────────────────────────────────────────────────────────────────

@description('The resource ID of the Container Apps environment')
output id string = containerAppsEnv.id

@description('The default domain of the Container Apps environment')
output defaultDomain string = containerAppsEnv.properties.defaultDomain

@description('The name of the Container Apps environment')
output name string = containerAppsEnv.name
