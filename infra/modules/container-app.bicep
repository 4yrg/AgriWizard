// ─────────────────────────────────────────────────────────────────────────────
// Module: Azure Container App (Reusable)
// ─────────────────────────────────────────────────────────────────────────────
// This module is called once per service (kong, iam, hardware, analytics,
// weather, notification, web). Each invocation creates one Container App
// with its specific configuration.
// ─────────────────────────────────────────────────────────────────────────────

@description('Name of the Container App')
param name string

@description('Azure region')
param location string = resourceGroup().location

@description('Tags to apply to the resource')
param tags object = {}

@description('Resource ID of the Container Apps environment')
param containerAppsEnvironmentId string

@description('Full image reference (e.g., myacr.azurecr.io/myapp:latest)')
param image string

@description('Container port to expose')
param targetPort int

@description('Whether ingress is external (public) or internal only')
param externalIngress bool = false

@description('CPU allocation (e.g., 0.25)')
param cpu string = '0.25'

@description('Memory allocation (e.g., 0.5Gi)')
param memory string = '0.5Gi'

@description('Minimum number of replicas')
param minReplicas int = 1

@description('Maximum number of replicas')
param maxReplicas int = 2

@description('Environment variables array')
param envVars array = []

@description('ACR login server')
param acrLoginServer string

@description('ACR admin username')
param acrUsername string

@secure()
@description('ACR admin password')
param acrPassword string

@description('Liveness probe path (empty to skip)')
param healthProbePath string = '/health'

// ─── Resource ────────────────────────────────────────────────────────────────

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: containerAppsEnvironmentId
    configuration: {
      ingress: {
        external: externalIngress
        targetPort: targetPort
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: acrLoginServer
          username: acrUsername
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: [
        {
          name: 'acr-password'
          value: acrPassword
        }
      ]
      activeRevisionsMode: 'Single'
    }
    template: {
      containers: [
        {
          name: name
          image: image
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          env: envVars
          probes: !empty(healthProbePath) ? [
            {
              type: 'Liveness'
              httpGet: {
                path: healthProbePath
                port: targetPort
              }
              initialDelaySeconds: 30
              periodSeconds: 15
              failureThreshold: 5
            }
            {
              type: 'Readiness'
              httpGet: {
                path: healthProbePath
                port: targetPort
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              failureThreshold: 3
            }
          ] : []
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }
  }
}

// ─── Outputs ─────────────────────────────────────────────────────────────────

@description('The FQDN of the Container App')
output fqdn string = containerApp.properties.configuration.ingress.fqdn

@description('The name of the Container App')
output name string = containerApp.name

@description('The resource ID')
output id string = containerApp.id

@description('The latest revision name')
output latestRevision string = containerApp.properties.latestRevisionName
