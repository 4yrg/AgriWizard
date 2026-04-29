// ─────────────────────────────────────────────────────────────────────────────
// Module: Azure Key Vault
// ─────────────────────────────────────────────────────────────────────────────

@description('Name of the Key Vault (must be globally unique)')
param name string

@description('Azure region')
param location string = resourceGroup().location

@description('Tags to apply to the resource')
param tags object = {}

@description('Principal ID of the Container Apps managed identity to grant access')
param containerAppsPrincipalId string = ''

// ─── Secrets to store ────────────────────────────────────────────────────────

@secure()
@description('PostgreSQL admin password')
param dbPassword string

@secure()
@description('JWT signing secret')
param jwtSecret string

@description('HiveMQ MQTT broker URL')
param mqttBroker string

@secure()
@description('HiveMQ MQTT username')
param mqttUsername string

@secure()
@description('HiveMQ MQTT password')
param mqttPassword string

@secure()
@description('Azure Service Bus connection string')
param serviceBusConnection string

@secure()
@description('OpenWeatherMap API key')
param owmApiKey string

// ─── Resource ────────────────────────────────────────────────────────────────

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    publicNetworkAccess: 'Enabled'
  }
}

// ─── Secrets ─────────────────────────────────────────────────────────────────

resource secretDbPassword 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'db-password'
  properties: {
    value: dbPassword
  }
}

resource secretJwtSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'jwt-secret'
  properties: {
    value: jwtSecret
  }
}

resource secretMqttBroker 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'mqtt-broker'
  properties: {
    value: mqttBroker
  }
}

resource secretMqttUsername 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'mqtt-username'
  properties: {
    value: mqttUsername
  }
}

resource secretMqttPassword 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'mqtt-password'
  properties: {
    value: mqttPassword
  }
}

resource secretServiceBusConnection 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'servicebus-connection'
  properties: {
    value: serviceBusConnection
  }
}

resource secretOwmApiKey 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'owm-api-key'
  properties: {
    value: owmApiKey
  }
}

// ─── RBAC: Grant Container Apps identity access to secrets ───────────────────

// Key Vault Secrets User role: 4633458b-17de-408a-b874-0445c86b69e6
resource secretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(containerAppsPrincipalId)) {
  name: guid(keyVault.id, containerAppsPrincipalId, '4633458b-17de-408a-b874-0445c86b69e6')
  scope: keyVault
  properties: {
    principalId: containerAppsPrincipalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalType: 'ServicePrincipal'
  }
}

// ─── Outputs ─────────────────────────────────────────────────────────────────

@description('The URI of the Key Vault')
output vaultUri string = keyVault.properties.vaultUri

@description('The name of the Key Vault')
output vaultName string = keyVault.name

@description('The resource ID of the Key Vault')
output id string = keyVault.id
