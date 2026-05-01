targetScope = 'resourceGroup'

@description('Deployment location.')
param location string = resourceGroup().location

@description('Container App name.')
param appName string

@description('Container Apps managed environment resource ID.')
param managedEnvironmentId string

@description('User-assigned managed identity resource ID.')
param identityResourceId string

@description('ACR login server.')
param acrLoginServer string

@description('Image name for the gateway.')
param imageName string = 'agriwizard-gateway'

@description('Image tag.')
param imageTag string = 'latest'

@description('CPU cores.')
param cpu string = '0.5'

@description('Memory.')
param memory string = '1Gi'

@description('Minimum replicas.')
param minReplicas int = 1

@description('Maximum replicas.')
param maxReplicas int = 3

@description('Container port.')
param containerPort int = 8080

var fqdnSuffix = 'yellowocean-38e04fed.centralindia.azurecontainerapps.io'

resource nginxApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: appName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityResourceId}': {}
    }
  }
  properties: {
    managedEnvironmentId: managedEnvironmentId
    configuration: {
      ingress: {
        external: true
        targetPort: containerPort
        transport: 'auto'
      }
      registries: [
        {
          server: acrLoginServer
          identity: identityResourceId
        }
      ]
    }
    template: {
      containers: [
        {
          name: appName
          image: '${acrLoginServer}/${imageName}:${imageTag}'
          env: [
            {
              name: 'IAM_SERVICE_HOST'
              value: 'iam-prod.${fqdnSuffix}'
            }
            {
              name: 'HARDWARE_SERVICE_HOST'
              value: 'hardware-prod.${fqdnSuffix}'
            }
            {
              name: 'ANALYTICS_SERVICE_HOST'
              value: 'analytics-prod.${fqdnSuffix}'
            }
            {
              name: 'WEATHER_SERVICE_HOST'
              value: 'weather-prod.${fqdnSuffix}'
            }
            {
              name: 'NOTIFICATION_SERVICE_HOST'
              value: 'notification-prod.${fqdnSuffix}'
            }
          ]
          resources: {
            cpu: json(cpu)
            memory: memory
          }
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }
  }
}

output fqdn string = nginxApp.properties.configuration.ingress.fqdn
output appName string = nginxApp.name