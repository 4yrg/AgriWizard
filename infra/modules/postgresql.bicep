// ─────────────────────────────────────────────────────────────────────────────
// Module: Azure Database for PostgreSQL Flexible Server
// ─────────────────────────────────────────────────────────────────────────────

@description('Name of the PostgreSQL server')
param name string

@description('Azure region')
param location string = resourceGroup().location

@description('Tags to apply to the resource')
param tags object = {}

@description('Administrator login name')
param administratorLogin string = 'agriwizard'

@secure()
@description('Administrator login password')
param administratorPassword string

@description('PostgreSQL version')
@allowed(['14', '15', '16'])
param version string = '16'

@description('SKU name (e.g., Standard_B1ms for burstable)')
param skuName string = 'Standard_B1ms'

@description('SKU tier')
@allowed(['Burstable', 'GeneralPurpose', 'MemoryOptimized'])
param skuTier string = 'Burstable'

@description('Storage size in GB')
param storageSizeGB int = 32

@description('Database name to create')
param databaseName string = 'agriwizard'

// ─── Resource: PostgreSQL Flexible Server ────────────────────────────────────

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-12-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    version: version
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    storage: {
      storageSizeGB: storageSizeGB
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
  }
}

// ─── Database ────────────────────────────────────────────────────────────────

resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-12-01-preview' = {
  parent: postgresServer
  name: databaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// ─── Firewall: Allow Azure Services ──────────────────────────────────────────

resource firewallAllowAzure 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-12-01-preview' = {
  parent: postgresServer
  name: 'AllowAllAzureServicesAndResourcesWithinAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ─── Outputs ─────────────────────────────────────────────────────────────────

@description('The fully qualified domain name of the PostgreSQL server')
output fqdn string = postgresServer.properties.fullyQualifiedDomainName

@description('The database name')
output databaseName string = database.name

@description('The administrator login')
output administratorLogin string = administratorLogin

@description('The resource ID')
output id string = postgresServer.id
