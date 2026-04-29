// ─────────────────────────────────────────────────────────────────────────────
// AgriWizard — Azure Infrastructure (Root Orchestrator)
// ─────────────────────────────────────────────────────────────────────────────
// Deploys all Azure resources for the AgriWizard Smart Greenhouse system:
//   - Azure Container Registry (ACR)
//   - Log Analytics Workspace
//   - Azure Key Vault
//   - Azure Database for PostgreSQL Flexible Server
//   - Azure Service Bus (topics + subscriptions)
//   - Container Apps Environment + 7 Container Apps
//
// External dependency (not managed here): HiveMQ Cloud (managed MQTT)
// ─────────────────────────────────────────────────────────────────────────────

targetScope = 'resourceGroup'

// ═════════════════════════════════════════════════════════════════════════════
// Parameters
// ═════════════════════════════════════════════════════════════════════════════

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Environment name prefix for resource naming')
param environmentName string = 'agriwizard'

@description('Container image tag to deploy')
param imageTag string = 'latest'

@description('Whether to use placeholder images (hello-world) if real images are missing from ACR')
param usePlaceholderImages bool = false

// ── Secrets ──────────────────────────────────────────────────────────────────

@secure()
@description('PostgreSQL administrator password')
param postgresAdminPassword string

@secure()
@description('JWT signing secret used by IAM and Kong')
param jwtSecret string

@description('HiveMQ Cloud MQTT broker URL (e.g., ssl://cluster.hivemq.cloud:8883)')
param mqttBroker string

@secure()
@description('HiveMQ Cloud MQTT username')
param mqttUsername string

@secure()
@description('HiveMQ Cloud MQTT password')
param mqttPassword string

@secure()
@description('OpenWeatherMap API key')
param owmApiKey string = ''

// ── SMTP configuration ──────────────────────────────────────────────────────

@description('SMTP host for notification emails')
param smtpHost string = ''

@description('SMTP port')
param smtpPort string = '587'

@description('SMTP from address')
param smtpFrom string = 'noreply@agriwizard.local'

@secure()
@description('SMTP username')
param smtpUsername string = ''

@secure()
@description('SMTP password')
param smtpPassword string = ''

// ── Location / Weather defaults ──────────────────────────────────────────────

@description('Latitude for weather service')
param locationLat string = '6.9271'

@description('Longitude for weather service')
param locationLon string = '79.8612'

@description('City name for weather service')
param locationCity string = 'Colombo'

// ═════════════════════════════════════════════════════════════════════════════
// Variables
// ═════════════════════════════════════════════════════════════════════════════

var tags = {
  project: 'agriwizard'
  environment: 'production'
  managedBy: 'bicep'
}

var acrName = 'agriwizardacr${uniqueString(resourceGroup().id)}'
var logAnalyticsName = '${environmentName}-logs'
var keyVaultName = '${environmentName}-kv'
var postgresName = '${environmentName}-postgres'
var serviceBusName = '${environmentName}-bus-ns'
var acaEnvName = '${environmentName}-aca-env'

// ═════════════════════════════════════════════════════════════════════════════
// Module 1: Container Registry
// ═════════════════════════════════════════════════════════════════════════════

module acr 'modules/container-registry.bicep' = {
  name: 'deploy-acr'
  params: {
    name: acrName
    location: location
    tags: tags
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Module 2: Log Analytics
// ═════════════════════════════════════════════════════════════════════════════

module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'deploy-log-analytics'
  params: {
    name: logAnalyticsName
    location: location
    tags: tags
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Module 3: PostgreSQL
// ═════════════════════════════════════════════════════════════════════════════

module postgres 'modules/postgresql.bicep' = {
  name: 'deploy-postgres'
  params: {
    name: postgresName
    location: location
    tags: tags
    administratorPassword: postgresAdminPassword
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Module 4: Service Bus
// ═════════════════════════════════════════════════════════════════════════════

module serviceBus 'modules/servicebus.bicep' = {
  name: 'deploy-servicebus'
  params: {
    name: serviceBusName
    location: location
    tags: tags
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Module 5: Key Vault
// ═════════════════════════════════════════════════════════════════════════════

module keyVault 'modules/keyvault.bicep' = {
  name: 'deploy-keyvault'
  params: {
    name: keyVaultName
    location: location
    tags: tags
    dbPassword: postgresAdminPassword
    jwtSecret: jwtSecret
    mqttBroker: mqttBroker
    mqttUsername: mqttUsername
    mqttPassword: mqttPassword
    serviceBusConnection: serviceBus.outputs.connectionString
    owmApiKey: owmApiKey
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Module 6: Container Apps Environment
// ═════════════════════════════════════════════════════════════════════════════

module acaEnv 'modules/container-apps-env.bicep' = {
  name: 'deploy-aca-env'
  params: {
    name: acaEnvName
    location: location
    tags: tags
    logAnalyticsCustomerId: logAnalytics.outputs.customerId
    logAnalyticsSharedKey: logAnalytics.outputs.sharedKey
  }
}

var acrLoginServer = acr.outputs.loginServer
var acrUsername = acr.outputs.adminUsername
var acrPassword = acr.outputs.adminPassword

// ── Placeholder Image Logic ──────────────────────────────────────────────────
var placeholderImage = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

// ═════════════════════════════════════════════════════════════════════════════
// Common env vars shared across all backend services
// ═════════════════════════════════════════════════════════════════════════════

var commonBackendEnv = [
  { name: 'DB_HOST', value: postgres.outputs.fqdn }
  { name: 'DB_PORT', value: '5432' }
  { name: 'DB_USER', value: 'agriwizard' }
  { name: 'DB_PASSWORD', value: postgresAdminPassword }
  { name: 'DB_NAME', value: 'agriwizard' }
  { name: 'DB_SSLMODE', value: 'require' }
  { name: 'JWT_SECRET', value: jwtSecret }
  { name: 'GIN_MODE', value: 'release' }
]

// ═════════════════════════════════════════════════════════════════════════════
// Module 7: Container Apps (one per service)
// ═════════════════════════════════════════════════════════════════════════════

// ── IAM Service ──────────────────────────────────────────────────────────────

module iamApp 'modules/container-app.bicep' = {
  name: 'deploy-app-iam'
  params: {
    name: '${environmentName}-iam'
    location: location
    tags: tags
    containerAppsEnvironmentId: acaEnv.outputs.id
    image: usePlaceholderImages ? placeholderImage : '${acrLoginServer}/${environmentName}-iam:${imageTag}'
    targetPort: 8086
    externalIngress: true
    cpu: '0.25'
    memory: '0.5Gi'
    minReplicas: 1
    maxReplicas: 2
    acrLoginServer: acrLoginServer
    acrUsername: acrUsername
    acrPassword: acrPassword
    envVars: concat(commonBackendEnv, [
      { name: 'PORT', value: '8086' }
      { name: 'JWT_ISSUER', value: 'agriwizard-iam' }
      { name: 'JWT_TTL_HOURS', value: '24' }
    ])
  }
}

// ── Hardware Service ─────────────────────────────────────────────────────────

module hardwareApp 'modules/container-app.bicep' = {
  name: 'deploy-app-hardware'
  params: {
    name: '${environmentName}-hardware'
    location: location
    tags: tags
    containerAppsEnvironmentId: acaEnv.outputs.id
    image: usePlaceholderImages ? placeholderImage : '${acrLoginServer}/${environmentName}-hardware:${imageTag}'
    targetPort: 8087
    externalIngress: true
    cpu: '0.25'
    memory: '0.5Gi'
    minReplicas: 1
    maxReplicas: 2
    acrLoginServer: acrLoginServer
    acrUsername: acrUsername
    acrPassword: acrPassword
    envVars: concat(commonBackendEnv, [
      { name: 'PORT', value: '8087' }
      { name: 'MQTT_BROKER', value: mqttBroker }
      { name: 'MQTT_USERNAME', value: mqttUsername }
      { name: 'MQTT_PASSWORD', value: mqttPassword }
      { name: 'ANALYTICS_SERVICE_URL', value: 'http://${environmentName}-analytics.internal.${acaEnv.outputs.defaultDomain}:8088' }
      { name: 'SERVICE_BUS_CONNECTION', value: serviceBus.outputs.connectionString }
      { name: 'SERVICE_BUS_TOPIC', value: 'telemetry' }
      { name: 'RABBITMQ_HOST', value: '' }
    ])
  }
}

// ── Analytics Service ────────────────────────────────────────────────────────

module analyticsApp 'modules/container-app.bicep' = {
  name: 'deploy-app-analytics'
  params: {
    name: '${environmentName}-analytics'
    location: location
    tags: tags
    containerAppsEnvironmentId: acaEnv.outputs.id
    image: usePlaceholderImages ? placeholderImage : '${acrLoginServer}/${environmentName}-analytics:${imageTag}'
    targetPort: 8088
    externalIngress: true
    cpu: '0.25'
    memory: '0.5Gi'
    minReplicas: 1
    maxReplicas: 2
    acrLoginServer: acrLoginServer
    acrUsername: acrUsername
    acrPassword: acrPassword
    envVars: concat(commonBackendEnv, [
      { name: 'PORT', value: '8088' }
      { name: 'HARDWARE_SERVICE_URL', value: 'http://${environmentName}-hardware.internal.${acaEnv.outputs.defaultDomain}:8087' }
      { name: 'WEATHER_SERVICE_URL', value: 'http://${environmentName}-weather.internal.${acaEnv.outputs.defaultDomain}:8089' }
      { name: 'SERVICE_BUS_CONNECTION', value: serviceBus.outputs.connectionString }
      { name: 'SERVICE_BUS_TOPIC', value: 'telemetry' }
      { name: 'SERVICE_BUS_SUBSCRIPTION', value: 'analytics-service' }
      { name: 'RABBITMQ_HOST', value: '' }
    ])
  }
}

// ── Weather Service ──────────────────────────────────────────────────────────

module weatherApp 'modules/container-app.bicep' = {
  name: 'deploy-app-weather'
  params: {
    name: '${environmentName}-weather'
    location: location
    tags: tags
    containerAppsEnvironmentId: acaEnv.outputs.id
    image: usePlaceholderImages ? placeholderImage : '${acrLoginServer}/${environmentName}-weather:${imageTag}'
    targetPort: 8089
    externalIngress: true
    cpu: '0.25'
    memory: '0.5Gi'
    minReplicas: 1
    maxReplicas: 1
    acrLoginServer: acrLoginServer
    acrUsername: acrUsername
    acrPassword: acrPassword
    envVars: concat(commonBackendEnv, [
      { name: 'PORT', value: '8089' }
      { name: 'USE_MOCK', value: 'false' }
      { name: 'OWM_API_KEY', value: owmApiKey }
      { name: 'OWM_BASE_URL', value: 'https://api.openweathermap.org/data/2.5' }
      { name: 'LOCATION_LAT', value: locationLat }
      { name: 'LOCATION_LON', value: locationLon }
      { name: 'LOCATION_CITY', value: locationCity }
    ])
  }
}

// ── Notification Service ─────────────────────────────────────────────────────

module notificationApp 'modules/container-app.bicep' = {
  name: 'deploy-app-notification'
  params: {
    name: '${environmentName}-notification'
    location: location
    tags: tags
    containerAppsEnvironmentId: acaEnv.outputs.id
    image: usePlaceholderImages ? placeholderImage : '${acrLoginServer}/${environmentName}-notification:${imageTag}'
    targetPort: 8091
    externalIngress: true
    cpu: '0.25'
    memory: '0.5Gi'
    minReplicas: 1
    maxReplicas: 1
    acrLoginServer: acrLoginServer
    acrUsername: acrUsername
    acrPassword: acrPassword
    envVars: [
      { name: 'PORT', value: '8091' }
      { name: 'DB_HOST', value: postgres.outputs.fqdn }
      { name: 'DB_PORT', value: '5432' }
      { name: 'DB_USER', value: 'agriwizard' }
      { name: 'DB_PASSWORD', value: postgresAdminPassword }
      { name: 'DB_NAME', value: 'agriwizard' }
      { name: 'DB_SSLMODE', value: 'require' }
      { name: 'NATS_URL', value: '' }
      { name: 'SMTP_HOST', value: smtpHost }
      { name: 'SMTP_PORT', value: smtpPort }
      { name: 'SMTP_FROM', value: smtpFrom }
      { name: 'SMTP_USERNAME', value: smtpUsername }
      { name: 'SMTP_PASSWORD', value: smtpPassword }
      { name: 'SERVICE_BUS_CONNECTION', value: serviceBus.outputs.connectionString }
      { name: 'SERVICE_BUS_TOPIC', value: 'notifications' }
      { name: 'SERVICE_BUS_SUBSCRIPTION', value: 'notification-service' }
      { name: 'RABBITMQ_HOST', value: '' }
    ]
  }
}

// ── Web Client (Next.js) ─────────────────────────────────────────────────────

module webApp 'modules/container-app.bicep' = {
  name: 'deploy-app-web'
  params: {
    name: '${environmentName}-web'
    location: location
    tags: tags
    containerAppsEnvironmentId: acaEnv.outputs.id
    image: usePlaceholderImages ? placeholderImage : '${acrLoginServer}/${environmentName}-web:${imageTag}'
    targetPort: 3000
    externalIngress: true
    cpu: '0.25'
    memory: '0.5Gi'
    minReplicas: 1
    maxReplicas: 2
    acrLoginServer: acrLoginServer
    acrUsername: acrUsername
    acrPassword: acrPassword
    healthProbePath: ''
    envVars: [
      { name: 'NODE_ENV', value: 'production' }
      { name: 'NEXT_PUBLIC_API_URL', value: apimGateway.outputs.gatewayUrl }
    ]
  }
}

// ── Azure API Management (APIM) ──────────────────────────────────────────────

module apimGateway 'modules/apim.bicep' = {
  name: 'deploy-apim'
  params: {
    name: '${environmentName}-apim'
    location: location
    tags: tags
    jwtSecret: jwtSecret
    iamFqdn: iamApp.outputs.fqdn
    hardwareFqdn: hardwareApp.outputs.fqdn
    analyticsFqdn: analyticsApp.outputs.fqdn
    weatherFqdn: weatherApp.outputs.fqdn
    notificationFqdn: notificationApp.outputs.fqdn
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Outputs
// ═════════════════════════════════════════════════════════════════════════════

@description('ACR login server')
output acrLoginServer string = acr.outputs.loginServer

@description('ACR name')
output acrName string = acrName

@description('Azure API Management Gateway URL')
output apimUrl string = apimGateway.outputs.gatewayUrl

@description('Web Client URL')
output webUrl string = 'https://${webApp.outputs.fqdn}'

@description('PostgreSQL FQDN')
output postgresFqdn string = postgres.outputs.fqdn

@description('Service Bus namespace')
output serviceBusNamespace string = serviceBus.outputs.namespaceName

@description('Key Vault name')
output keyVaultName string = keyVault.outputs.vaultName

@description('Container Apps Environment default domain')
output acaDefaultDomain string = acaEnv.outputs.defaultDomain
