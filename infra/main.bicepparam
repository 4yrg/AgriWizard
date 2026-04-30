using './main.bicep'

param namePrefix = 'agriwizard'
param location = 'centralindia'
param environmentSuffix = 'prod'
param acrSku = 'Standard'

param backendServices = [
  {
    serviceName: 'iam'
    imageName: 'agriwizard-iam'
    imageTag: 'latest'
    containerPort: 8086
    cpu: '0.5'
    memory: '1Gi'
    minReplicas: 1
    maxReplicas: 3
    externalIngress: true
    environmentVariables: [
      {
        name: 'PORT'
        value: '8086'
      }
      {
        name: 'JWT_TTL_HOURS'
        value: '24'
      }
    ]
  }
  {
    serviceName: 'hardware'
    imageName: 'agriwizard-hardware'
    imageTag: 'latest'
    containerPort: 8087
    cpu: '0.5'
    memory: '1Gi'
    minReplicas: 1
    maxReplicas: 3
    externalIngress: true
    environmentVariables: [
      {
        name: 'PORT'
        value: '8087'
      }
      {
        name: 'DB_PORT'
        value: '5432'
      }
      {
        name: 'DB_NAME'
        value: 'agriwizard'
      }
      {
        name: 'DB_SSLMODE'
        value: 'require'
      }
      {
        name: 'ANALYTICS_SERVICE_URL'
        value: 'http://analytics-prod'
      }
    ]
  }
  {
    serviceName: 'analytics'
    imageName: 'agriwizard-analytics'
    imageTag: 'latest'
    containerPort: 8088
    cpu: '0.5'
    memory: '1Gi'
    minReplicas: 1
    maxReplicas: 3
    externalIngress: true
    environmentVariables: [
      {
        name: 'PORT'
        value: '8088'
      }
      {
        name: 'DB_PORT'
        value: '5432'
      }
      {
        name: 'DB_NAME'
        value: 'agriwizard'
      }
      {
        name: 'DB_SSLMODE'
        value: 'require'
      }
      {
        name: 'HARDWARE_SERVICE_URL'
        value: 'http://hardware-prod'
      }
      {
        name: 'WEATHER_SERVICE_URL'
        value: 'http://weather-prod'
      }
    ]
  }
  {
    serviceName: 'weather'
    imageName: 'agriwizard-weather'
    imageTag: 'latest'
    containerPort: 8089
    cpu: '0.5'
    memory: '1Gi'
    minReplicas: 1
    maxReplicas: 3
    externalIngress: true
    environmentVariables: [
      {
        name: 'PORT'
        value: '8089'
      }
      {
        name: 'USE_MOCK'
        value: 'false'
      }
      {
        name: 'OWM_BASE_URL'
        value: 'https://api.openweathermap.org/data/2.5'
      }
      {
        name: 'LOCATION_LAT'
        value: '6.9271'
      }
      {
        name: 'LOCATION_LON'
        value: '79.8612'
      }
      {
        name: 'LOCATION_CITY'
        value: 'Colombo'
      }
    ]
  }
  {
    serviceName: 'notification'
    imageName: 'agriwizard-notification'
    imageTag: 'latest'
    containerPort: 8091
    cpu: '0.5'
    memory: '1Gi'
    minReplicas: 1
    maxReplicas: 3
    externalIngress: true
    environmentVariables: [
      {
        name: 'PORT'
        value: '8091'
      }
      {
        name: 'DB_PORT'
        value: '5432'
      }
      {
        name: 'DB_NAME'
        value: 'agriwizard'
      }
      {
        name: 'DB_SSLMODE'
        value: 'require'
      }
      {
        name: 'SMTP_HOST'
        value: 'smtp.gmail.com'
      }
      {
        name: 'SMTP_PORT'
        value: '587'
      }
      {
        name: 'SMTP_FROM'
        value: 'jsamuditha@gmail.com'
      }
      {
        name: 'NATS_URL'
        value: 'nats://nats:4222'
      }
    ]
  }
]

param dbPassword string = ''
param jwtSecret string = ''
param mqttPassword string = ''
param owmApiKey string = ''
param smtpPassword string = ''
param smtpUsername string = 'jsamuditha@gmail.com'
param serviceBusConnection string = ''
