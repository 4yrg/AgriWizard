targetScope = 'resourceGroup'

@description('Key Vault name.')
param keyVaultName string

@description('Deployment location.')
param location string = resourceGroup().location

@description('Azure tenant ID.')
param tenantId string

@description('Database password.')
@secure()
param dbPassword string = ''

@description('JWT secret.')
@secure()
param jwtSecretParam string = ''

@description('MQTT password.')
@secure()
param mqttPassword string = ''

@description('SMTP password.')
@secure()
param smtpPassword string = ''

@description('Service Bus connection string.')
@secure()
param serviceBusConnection string = ''

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource dbPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (!empty(dbPassword)) {
  parent: keyVault
  name: 'db-password'
  properties: {
    value: dbPassword
  }
}

resource jwtSecretResource 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (!empty(jwtSecretParam)) {
  parent: keyVault
  name: 'jwt-secret'
  properties: {
    value: jwtSecretParam
  }
}

resource mqttPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (!empty(mqttPassword)) {
  parent: keyVault
  name: 'mqtt-password'
  properties: {
    value: mqttPassword
  }
}

resource smtpPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (!empty(smtpPassword)) {
  parent: keyVault
  name: 'smtp-password'
  properties: {
    value: smtpPassword
  }
}

resource serviceBusConnectionSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (!empty(serviceBusConnection)) {
  parent: keyVault
  name: 'sb-connection'
  properties: {
    value: serviceBusConnection
  }
}

output keyVaultId string = keyVault.id
output keyVaultNameOut string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri