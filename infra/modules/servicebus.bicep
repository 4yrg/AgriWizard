targetScope = 'resourceGroup'

@description('Service Bus namespace name.')
param serviceBusName string

@description('Deployment location.')
param location string = resourceGroup().location

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01' = {
  name: serviceBusName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {}
}

// Topic: telemetry (hardware -> analytics)
resource telemetryTopic 'Microsoft.ServiceBus/namespaces/topics@2022-10-01' = {
  parent: serviceBusNamespace
  name: 'telemetry'
  properties: {
    maxSizeInMegabytes: 1024
    defaultMessageTimeToLive: 'P1D'
    maxMessageSizeInKilobytes: 256
  }
}

resource analyticsSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01' = {
  parent: telemetryTopic
  name: 'analytics-service'
  properties: {
    lockDuration: 'PT30S'
    maxDeliveryCount: 10
    defaultMessageTimeToLive: 'P1D'
    deadLetteringOnMessageExpiration: true
    deadLetteringOnFilterEvaluationExceptions: false
  }
}

// Topic: notifications (for notification service)
resource notificationsTopic 'Microsoft.ServiceBus/namespaces/topics@2022-10-01' = {
  parent: serviceBusNamespace
  name: 'notifications'
  properties: {
    maxSizeInMegabytes: 1024
    defaultMessageTimeToLive: 'P1D'
    maxMessageSizeInKilobytes: 256
  }
}

resource notificationSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01' = {
  parent: notificationsTopic
  name: 'notification-service'
  properties: {
    lockDuration: 'PT30S'
    maxDeliveryCount: 10
    defaultMessageTimeToLive: 'P1D'
    deadLetteringOnMessageExpiration: true
    deadLetteringOnFilterEvaluationExceptions: false
  }
}

// Get connection string with SAS policy
resource sbPolicy 'Microsoft.ServiceBus/namespaces/authorizationRules@2022-10-01' = {
  parent: serviceBusNamespace
  name: 'RootManageSharedAccessKey'
  properties: {
    rights: [
      'Manage'
      'Listen'
      'Send'
    ]
  }
}

var connectionString = 'Endpoint=sb://${serviceBusNamespace.name}.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=${listKeys(resourceId('Microsoft.ServiceBus/namespaces/authorizationRules', serviceBusNamespace.name, 'RootManageSharedAccessKey'), '2022-10-01').primaryKey}'

output serviceBusId string = serviceBusNamespace.id
output serviceBusNameOut string = serviceBusNamespace.name
output connectionString string = connectionString
output telemetryTopicName string = telemetryTopic.name
output notificationsTopicName string = notificationsTopic.name