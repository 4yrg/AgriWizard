targetScope = 'subscription'

@description('Name prefix for all resources.')
param namePrefix string

@description('Deployment location.')
param location string

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
param acrName string

var resourceGroupName = '${namePrefix}-${environmentSuffix}-rg'
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
    location: location
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
    acrName: acrName
    sku: acrSku
    pullPrincipalId: identity.outputs.principalId
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

module apps './modules/aca-app.bicep' = [for service in backendServices: {
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
    secrets: [
      {
        name: 'db-password'
      }
      {
        name: 'jwt-secret'
      }
      {
        name: 'mqtt-password'
      }
      {
        name: 'owm-api-key'
      }
      {
        name: 'smtp-password'
      }
      {
        name: 'service-bus-connection'
      }
    ]
    secretValues: {
      'db-password': dbPassword
      'jwt-secret': jwtSecret
      'mqtt-password': mqttPassword
      'owm-api-key': owmApiKey
      'smtp-password': smtpPassword
      'service-bus-connection': serviceBusConnection
    }
    environmentVariables: concat(service.environmentVariables, [
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
        name: 'SMTP_PASSWORD'
        secretRef: 'smtp-password'
      }
      {
        name: 'SERVICE_BUS_CONNECTION'
        secretRef: 'service-bus-connection'
      }
    ])
    externalIngress: service.externalIngress
  }
}]

output resourceGroupName string = resourceGroupName
output acrName string = acr.outputs.acrNameOut
output acrLoginServer string = acr.outputs.acrLoginServer
output identityClientId string = identity.outputs.clientId
output containerAppFqdns array = [for (service, i) in backendServices: {
  serviceName: service.serviceName
  containerAppName: '${service.serviceName}-${environmentSuffix}'
  fqdn: apps[i].outputs.fqdn
}]
