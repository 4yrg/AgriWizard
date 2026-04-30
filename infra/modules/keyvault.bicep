targetScope = 'resourceGroup'

@description('Key Vault name.')
param keyVaultName string

@description('Deployment location.')
param location string

@description('Azure tenant ID.')
param tenantId string

@description('Database password.')
@secure()
param dbPassword string

@description('JWT secret.')
@secure()
param jwtSecretParam string

@description('MQTT password.')
@secure()
param mqttPassword string

@description('SMTP password.')
@secure()
param smtpPassword string

@description('Service Bus connection string.')
@secure()
param serviceBusConnection string

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
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
    softDeleteRetentionInDays: 90
    enablePurgeProtection: false
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource dbPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'db-password'
  properties: {
    value: dbPassword
    contentType: 'string'
  }
}

resource jwtSecretResource 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'jwt-secret'
  properties: {
    value: jwtSecretParam
    contentType: 'string'
  }
}

resource mqttPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'mqtt-password'
  properties: {
    value: mqttPassword
    contentType: 'string'
  }
}

resource smtpPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'smtp-password'
  properties: {
    value: smtpPassword
    contentType: 'string'
  }
}

resource serviceBusConnectionSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'servicebus-connection'
  properties: {
    value: serviceBusConnection
    contentType: 'string'
  }
}

output keyVaultId string = keyVault.id
output keyVaultNameOut string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri