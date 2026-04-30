targetScope = 'resourceGroup'

@description('Deployment location.')
param location string = resourceGroup().location

@description('Container App name.')
param appName string

@description('Container Apps managed environment resource ID.')
param managedEnvironmentId string

@description('User-assigned managed identity resource ID.')
param identityResourceId string

@description('ACR login server (for example myacr.azurecr.io).')
param acrLoginServer string

@description('Service name used for container naming.')
param serviceName string

@description('Image name without login server.')
param imageName string

@description('Image tag.')
param imageTag string

@description('Container port.')
param containerPort int

@description('CPU cores as string value (for example 0.5, 1.0).')
param cpu string

@description('Memory in Gi (for example 1Gi, 2Gi).')
param memory string

@description('Minimum replicas.')
param minReplicas int

@description('Maximum replicas.')
param maxReplicas int

@description('ACA secrets array: [{ name: string, value: string }].')
param secrets array = []

@description('Secure object containing secret values keyed by secret name.')
@secure()
param secretValues object = {}

@description('Environment variables array: [{ name: string, value?: string, secretRef?: string }].')
param environmentVariables array = []

@description('Set to true for public ingress.')
param externalIngress bool = true

@description('Path for health probes.')
param healthPath string = '/health'

resource app 'Microsoft.App/containerApps@2024-03-01' = {
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
        external: externalIngress
        targetPort: containerPort
        transport: 'auto'
      }
      registries: [
        {
          server: acrLoginServer
          identity: identityResourceId
        }
      ]
      secrets: [for s in secrets: {
        name: s.name
        #disable-next-line use-secure-value-for-secure-inputs
        value: secretValues[s.name]
      }]
    }
    template: {
      containers: [
        {
          name: serviceName
          image: imageName == 'kong' ? 'kong:${imageTag}' : '${acrLoginServer}/${imageName}:${imageTag}'
          env: [for envVar in environmentVariables: union({
            name: envVar.name
          }, (contains(envVar, 'value') && !empty(envVar.value) ? { value: envVar.value } : {}), (contains(envVar, 'secretRef') && !empty(envVar.secretRef) ? { secretRef: envVar.secretRef } : {}))]
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: healthPath
                port: containerPort
              }
              initialDelaySeconds: 15
              periodSeconds: 30
            }
            {
              type: 'Readiness'
              httpGet: {
                path: healthPath
                port: containerPort
              }
              initialDelaySeconds: 10
              periodSeconds: 10
            }
            {
              type: 'Startup'
              httpGet: {
                path: healthPath
                port: containerPort
              }
              initialDelaySeconds: 5
              periodSeconds: 5
              failureThreshold: 20
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }
  }
}

output appNameOut string = app.name
output fqdn string = externalIngress ? app.properties.configuration.ingress.fqdn : ''
