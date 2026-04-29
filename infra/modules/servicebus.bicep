// ─────────────────────────────────────────────────────────────────────────────
// Module: Azure Service Bus Namespace + Topics + Subscriptions
// ─────────────────────────────────────────────────────────────────────────────
// Replaces RabbitMQ + NATS from local dev. The Go services already have
// Azure Service Bus client code (servicebus.go) that activates when
// SERVICE_BUS_CONNECTION is set.
// ─────────────────────────────────────────────────────────────────────────────

@description('Name of the Service Bus namespace')
param name string

@description('Azure region')
param location string = resourceGroup().location

@description('Tags to apply to the resource')
param tags object = {}

@description('SKU tier — Standard required for topics')
@allowed(['Basic', 'Standard', 'Premium'])
param sku string = 'Standard'

// ─── Resource: Namespace ─────────────────────────────────────────────────────

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
    tier: sku
  }
  properties: {}
}

// ─── Topic: telemetry ────────────────────────────────────────────────────────
// hardware-service publishes telemetry events here

resource telemetryTopic 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'telemetry'
  properties: {
    defaultMessageTimeToLive: 'P1D'       // 1 day TTL
    maxSizeInMegabytes: 1024
    enablePartitioning: false
  }
}

// Subscription: analytics-service consumes telemetry for threshold checks
resource telemetrySubAnalytics 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: telemetryTopic
  name: 'analytics-service'
  properties: {
    deadLetteringOnMessageExpiration: true
    defaultMessageTimeToLive: 'P1D'
    maxDeliveryCount: 5
    lockDuration: 'PT1M'
  }
}

// Subscription: notification-service for telemetry-triggered alerts (optional fan-out)
resource telemetrySubNotification 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: telemetryTopic
  name: 'notification-service'
  properties: {
    deadLetteringOnMessageExpiration: true
    defaultMessageTimeToLive: 'P1D'
    maxDeliveryCount: 5
    lockDuration: 'PT1M'
  }
}

// ─── Topic: notifications ────────────────────────────────────────────────────
// notification-service consumes notification dispatch requests here

resource notificationsTopic 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'notifications'
  properties: {
    defaultMessageTimeToLive: 'P1D'
    maxSizeInMegabytes: 1024
    enablePartitioning: false
  }
}

// Subscription: notification-service consumes notification requests
resource notificationsSubService 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: notificationsTopic
  name: 'notification-service'
  properties: {
    deadLetteringOnMessageExpiration: true
    defaultMessageTimeToLive: 'P1D'
    maxDeliveryCount: 5
    lockDuration: 'PT1M'
  }
}

// ─── Authorization Rule (for connection string) ──────────────────────────────

resource authRule 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'agriwizard-apps'
  properties: {
    rights: [
      'Send'
      'Listen'
      'Manage'
    ]
  }
}

// ─── Outputs ─────────────────────────────────────────────────────────────────

@description('The primary connection string for the Service Bus namespace')
#disable-next-line outputs-should-not-contain-secrets
output connectionString string = authRule.listKeys().primaryConnectionString

@description('The name of the Service Bus namespace')
output namespaceName string = serviceBusNamespace.name

@description('The resource ID')
output id string = serviceBusNamespace.id
