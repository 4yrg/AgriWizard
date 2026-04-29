// ─────────────────────────────────────────────────────────────────────────────
// Module: Log Analytics Workspace
// ─────────────────────────────────────────────────────────────────────────────

@description('Name of the Log Analytics workspace')
param name string

@description('Azure region')
param location string = resourceGroup().location

@description('Retention period in days')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Tags to apply to the resource')
param tags object = {}

// ─── Resource ────────────────────────────────────────────────────────────────

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ─── Outputs ─────────────────────────────────────────────────────────────────

@description('The resource ID of the Log Analytics workspace')
output id string = logAnalytics.id

@description('The customer ID (workspace ID) used by Container Apps')
output customerId string = logAnalytics.properties.customerId

@description('The shared key for the Log Analytics workspace')
#disable-next-line outputs-should-not-contain-secrets
output sharedKey string = logAnalytics.listKeys().primarySharedKey
