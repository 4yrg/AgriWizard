@description('Name of the PostgreSQL Flexible Server.')
param serverName string

@description('Location for the resource.')
param location string = resourceGroup().location

@description('Administrator username.')
param adminUsername string

@description('Administrator password.')
@secure()
param adminPassword string

@description('The SKU of the PostgreSQL server.')
param skuName string = 'Standard_B1ms'

@description('The version of PostgreSQL.')
param version string = '15'

@description('Storage size in GB.')
param storageSizeGB int = 32

resource server 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  name: serverName
  location: location
  sku: {
    name: skuName
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword
    version: version
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

resource firewallRule 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2022-12-01' = {
  parent: server
  name: 'AllowAllAzureInternal'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

output serverName string = server.name
output fullyQualifiedDomainName string = server.properties.fullyQualifiedDomainName
output serverNameOutput string = server.name
