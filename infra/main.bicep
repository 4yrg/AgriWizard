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

@description('SMTP username.')
param smtpUsername string

@description('Service Bus connection string.')
@secure()
param serviceBusConnection string

@description('DB administrator username.')
param dbUser string = 'agriwizard_admin'

@description('The name of the ACR.')
param acrName string = ''

@description('Azure tenant ID.')
param tenantId string = ''

@description('Global image tag override (e.g. github.sha).')
param globalImageTag string = ''

@description('Gateway image tag.')
param gatewayImageTag string = 'latest'

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
  { name: 'smtp-username' }
]

var secretValueMap = {
  'db-password': hasDbPassword ? dbPassword : 'temp'
  'jwt-secret': hasJwtSecret ? jwtSecret : 'temp'
  'mqtt-password': hasMqttPassword ? mqttPassword : 'temp'
  'owm-api-key': hasOwmApiKey ? owmApiKey : 'temp'
  'service-bus-connection': hasServiceBus ? serviceBusConnection : servicebus.outputs.connectionString
  'smtp-password': hasSmtpPassword ? smtpPassword : 'temp'
  'smtp-username': !empty(smtpUsername) ? smtpUsername : 'temp'
}
var serviceBusName = take('${namePrefix}-${environmentSuffix}-sb-${uniqueSuffix}', 50)
var keyVaultName = take('kv${uniqueSuffix}', 24)
var managedEnvironmentName = '${namePrefix}-${environmentSuffix}-aca-env'
var logAnalyticsWorkspaceName = '${namePrefix}-${environmentSuffix}-law'
var identityName = '${namePrefix}-${environmentSuffix}-aca-mi'
var dbServerName = take('${namePrefix}-${environmentSuffix}-db-${uniqueSuffix}', 50)
var nginxGatewayName = '${namePrefix}-${environmentSuffix}-gateway'

module rg './modules/resource-group.bicep' = {
  name: 'resource-group'
  params: {
    location: location
    resourceGroupName: resourceGroupName
  }
}

// Compute per-service DB names
var dbNames = [for s in backendServices: take('${namePrefix}-${s.serviceName}-${environmentSuffix}', 50)]

module postgresql './modules/postgresql.bicep' = {
  name: 'postgresql'
  scope: resourceGroup(resourceGroupName)
  params: {
    serverName: dbServerName
    adminUsername: dbUser
    adminPassword: dbPassword
    databaseNames: dbNames
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

// Core backend services
module coreApps './modules/aca-app.bicep' = [for (service, i) in backendServices: if (service.serviceName != 'kong') {
  name: 'deploy-core-${service.serviceName}'
  scope: resourceGroup(resourceGroupName)
  params: {
    appName: '${service.serviceName}-${environmentSuffix}'
    managedEnvironmentId: acaEnvironment.outputs.managedEnvironmentId
    identityResourceId: identity.outputs.identityId
    acrLoginServer: acr.outputs.acrLoginServer
    serviceName: service.serviceName
    imageName: service.imageName
    imageTag: (service.serviceName == 'kong') ? service.imageTag : (empty(globalImageTag) ? service.imageTag : globalImageTag)
    containerPort: service.containerPort
    cpu: service.cpu
    memory: service.memory
    minReplicas: service.minReplicas
    maxReplicas: service.maxReplicas
    secrets: appSecrets
    secretValues: secretValueMap
    environmentVariables: union(service.environmentVariables, [
      {
        name: 'PORT'
        value: string(service.containerPort)
      }
      {
        name: 'DB_HOST'
        value: postgresql.outputs.fullyQualifiedDomainName
      }
      {
        name: 'DB_USER'
        value: dbUser
      }
      {
        name: 'DB_NAME'
        value: dbNames[i]
      }
      {
        name: 'CORS_ALLOW_ORIGIN'
        value: 'https://agri-wizard.vercel.app'
      }
      // Secret mappings
      {
        name: 'DB_PASSWORD'
        secretRef: 'db-password'
      }
      {
        name: 'JWT_SECRET'
        secretRef: 'jwt-secret'
      }
      {
        name: 'MQTT_PASSWORD'
        secretRef: 'mqtt-password'
      }
      {
        name: 'OWM_API_KEY'
        secretRef: 'owm-api-key'
      }
      {
        name: 'SERVICE_BUS_CONNECTION'
        secretRef: 'service-bus-connection'
      }
      {
        name: 'SMTP_PASSWORD'
        secretRef: 'smtp-password'
      }
      {
        name: 'SMTP_USERNAME'
        secretRef: 'smtp-username'
      }
    ])
    externalIngress: false
  }
}]

// Nginx Gateway (replaces APIM)
module gateway './modules/nginx.bicep' = {
  name: 'nginx-gateway'
  scope: resourceGroup(resourceGroupName)
  params: {
    appName: nginxGatewayName
    managedEnvironmentId: acaEnvironment.outputs.managedEnvironmentId
    identityResourceId: identity.outputs.identityId
    acrLoginServer: acr.outputs.acrLoginServer
    imageName: 'agriwizard-gateway'
    imageTag: empty(globalImageTag) ? gatewayImageTag : globalImageTag
    containerPort: 8080
    cpu: '0.5'
    memory: '1Gi'
    minReplicas: 1
    maxReplicas: 3
  }
  dependsOn: [
    coreApps
  ]
}

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
  fqdn: ''
}]
output dbHost string = postgresql.outputs.fullyQualifiedDomainName
output dbPort string = '5432'
output dbNames array = [for (s, i) in backendServices: {
  serviceName: s.serviceName
  dbName: dbNames[i]
}]
output dbUser string = dbUser
output gatewayUrl string = 'https://${gateway.outputs.fqdn}'
output gatewayFqdn string = gateway.outputs.fqdn
output identityId string = identity.outputs.identityId
