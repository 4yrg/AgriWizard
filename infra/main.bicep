targetScope = 'subscription'

@description('Name prefix for all resources.')
param namePrefix string

@description('Deployment location.')
param location string = deployment().location

@description('Short environment suffix. Must remain prod-only.')
param environmentSuffix string = 'prod'

@description('ACR SKU.')
param acrSku string = 'Standard'

@description('ACA app definitions for backend services only.')
param backendServices array

@description('DB password shared by backend services.')
@secure()
param dbPassword string

@description('JWT secret shared by backend services.')
@secure()
param jwtSecret string

@description('MQTT password.')
@secure()
param mqttPassword string

@description('OpenWeather API key.')
@secure()
param owmApiKey string

@description('SMTP password.')
@secure()
param smtpPassword string

@description('Service Bus connection string.')
@secure()
param serviceBusConnection string

@description('DB administrator username.')
param dbUser string = 'agriwizard_admin'

@description('The name of the ACR.')
param acrName string = ''

@description('Azure tenant ID.')
param tenantId string = ''

var uniqueSuffix = uniqueString(subscription().id, resourceGroupName)
var computedAcrName = empty(acrName) ? take('${namePrefix}acr${uniqueSuffix}', 50) : acrName
var computedTenantId = empty(tenantId) ? subscription().tenantId : tenantId

var resourceGroupName = '${namePrefix}-${environmentSuffix}-rg'

var hasDbPassword = !empty(dbPassword)
var hasJwtSecret = !empty(jwtSecret)
var hasMqttPassword = !empty(mqttPassword)
var hasOwmApiKey = !empty(owmApiKey)
var hasServiceBus = !empty(serviceBusConnection)
var hasSmtpPassword = !empty(smtpPassword)

var appSecrets = [
  { name: 'db-password' }
  { name: 'jwt-secret' }
  { name: 'mqtt-password' }
  { name: 'owm-api-key' }
  { name: 'service-bus-connection' }
  { name: 'smtp-password' }
]

var secretValueMap = {
  'db-password': hasDbPassword ? dbPassword : 'temp'
  'jwt-secret': hasJwtSecret ? jwtSecret : 'temp'
  'mqtt-password': hasMqttPassword ? mqttPassword : 'temp'
  'owm-api-key': hasOwmApiKey ? owmApiKey : 'temp'
  'service-bus-connection': hasServiceBus ? serviceBusConnection : servicebus.outputs.connectionString
  'smtp-password': hasSmtpPassword ? smtpPassword : 'temp'
}
var serviceBusName = take('${namePrefix}-${environmentSuffix}-sb-${uniqueSuffix}', 50)
var keyVaultName = take('${namePrefix}-${environmentSuffix}-kv-${uniqueSuffix}', 24)
var managedEnvironmentName = '${namePrefix}-${environmentSuffix}-aca-env'
var logAnalyticsWorkspaceName = '${namePrefix}-${environmentSuffix}-law'
var identityName = '${namePrefix}-${environmentSuffix}-aca-mi'
var dbServerName = '${namePrefix}-${environmentSuffix}-db'

module rg './modules/resource-group.bicep' = {
  name: 'resource-group'
  params: {
    location: location
    resourceGroupName: resourceGroupName
  }
}

module postgresql './modules/postgresql.bicep' = {
  name: 'postgresql'
  scope: resourceGroup(resourceGroupName)
  params: {
    serverName: dbServerName
    adminUsername: dbUser
    adminPassword: dbPassword
  }
  dependsOn: [
    rg
  ]
}

module identity './modules/identity.bicep' = {
  name: 'identity'
  scope: resourceGroup(resourceGroupName)
  params: {
    identityName: identityName
  }
  dependsOn: [
    rg
  ]
}

module acr './modules/acr.bicep' = {
  name: 'acr'
  scope: resourceGroup(resourceGroupName)
  params: {
    acrName: computedAcrName
    sku: acrSku
    pullPrincipalId: identity.outputs.principalId
  }
}

module servicebus './modules/servicebus.bicep' = {
  name: 'servicebus'
  scope: resourceGroup(resourceGroupName)
  params: {
    serviceBusName: serviceBusName
  }
}

module keyvault './modules/keyvault.bicep' = {
  name: 'keyvault'
  scope: resourceGroup(resourceGroupName)
  params: {
    keyVaultName: keyVaultName
    tenantId: computedTenantId
    dbPassword: dbPassword
    jwtSecretParam: jwtSecret
    mqttPassword: mqttPassword
    smtpPassword: smtpPassword
    serviceBusConnection: servicebus.outputs.connectionString
  }
}

module acaEnvironment './modules/aca-environment.bicep' = {
  name: 'aca-environment'
  scope: resourceGroup(resourceGroupName)
  params: {
    managedEnvironmentName: managedEnvironmentName
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
  }
  dependsOn: [
    rg
  ]
}

module coreApps './modules/aca-app.bicep' = [for service in backendServices: if (service.serviceName != 'kong') {
  name: 'aca-app-${service.serviceName}'
  scope: resourceGroup(resourceGroupName)
  params: {
    appName: '${service.serviceName}-${environmentSuffix}'
    managedEnvironmentId: acaEnvironment.outputs.managedEnvironmentId
    identityResourceId: identity.outputs.identityId
    acrLoginServer: acr.outputs.acrLoginServer
    serviceName: service.serviceName
    imageName: service.imageName
    imageTag: service.imageTag
    containerPort: service.containerPort
    cpu: service.cpu
    memory: service.memory
    minReplicas: service.minReplicas
    maxReplicas: service.maxReplicas
    secrets: appSecrets
    secretValues: secretValueMap
    environmentVariables: union(service.environmentVariables, [
      {
        name: 'DB_HOST'
        value: postgresql.outputs.fullyQualifiedDomainName
      }
      {
        name: 'DB_USER'
        value: dbUser
      }
      {
        name: 'CORS_ALLOW_ORIGIN'
        value: 'https://agri-wizard.vercel.app'
      }
    ])
    externalIngress: service.externalIngress
  }
  dependsOn: [
    postgresql
    servicebus
    keyvault
  ]
}]

module gatewayApp './modules/aca-app.bicep' = [for service in backendServices: if (service.serviceName == 'kong') {
  name: 'aca-app-kong'
  scope: resourceGroup(resourceGroupName)
  params: {
    appName: '${service.serviceName}-${environmentSuffix}'
    managedEnvironmentId: acaEnvironment.outputs.managedEnvironmentId
    identityResourceId: identity.outputs.identityId
    acrLoginServer: acr.outputs.acrLoginServer
    serviceName: service.serviceName
    imageName: service.imageName
    imageTag: service.imageTag
    containerPort: service.containerPort
    cpu: service.cpu
    memory: service.memory
    minReplicas: service.minReplicas
    maxReplicas: service.maxReplicas
    secrets: appSecrets
    secretValues: secretValueMap
    environmentVariables: union(service.environmentVariables, [
      {
        name: 'DB_HOST'
        value: postgresql.outputs.fullyQualifiedDomainName
      }
      {
        name: 'DB_USER'
        value: dbUser
      }
      {
        name: 'CORS_ALLOW_ORIGIN'
        value: 'https://agri-wizard.vercel.app'
      }
    ])
    externalIngress: service.externalIngress
  }
  dependsOn: [
    coreApps
  ]
}]

output resourceGroupName string = resourceGroupName
output acrName string = acr.outputs.acrNameOut
output acrLoginServer string = acr.outputs.acrLoginServer
output serviceBusName string = servicebus.outputs.serviceBusNameOut
output keyVaultName string = keyvault.outputs.keyVaultNameOut
output keyVaultUri string = keyvault.outputs.keyVaultUri
output identityClientId string = identity.outputs.clientId
output containerAppFqdns array = [for (service, i) in backendServices: {
  serviceName: service.serviceName
  containerAppName: '${service.serviceName}-${environmentSuffix}'
  fqdn: service.serviceName == 'kong' ? gatewayApp[0].outputs.fqdn : coreApps[service.serviceName == 'iam' ? 0 : (service.serviceName == 'hardware' ? 1 : (service.serviceName == 'analytics' ? 2 : (service.serviceName == 'weather' ? 3 : (service.serviceName == 'notification' ? 4 : 0))))].outputs.fqdn
}]
