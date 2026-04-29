// ─────────────────────────────────────────────────────────────────────────────
// Module: Application Insights (Workspace-based)
// ─────────────────────────────────────────────────────────────────────────────

@description('Name of the Application Insights resource')
param name string

@description('Azure region')
param location string = resourceGroup().location

@description('Resource ID of the Log Analytics workspace')
param workspaceResourceId string

@description('Tags to apply to the resource')
param tags object = {}

// ─── Resource ────────────────────────────────────────────────────────────────

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspaceResourceId
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ─── Outputs ─────────────────────────────────────────────────────────────────

@description('The resource ID of the Application Insights resource')
output id string = appInsights.id

@description('The instrumentation key')
#disable-next-line outputs-should-not-contain-secrets
output instrumentationKey string = appInsights.properties.InstrumentationKey

@description('The connection string')
#disable-next-line outputs-should-not-contain-secrets
output connectionString string = appInsights.properties.ConnectionString
