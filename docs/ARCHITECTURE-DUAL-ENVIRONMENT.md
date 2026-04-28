# AgriWizard - Dual Environment Architecture

## Overview

AgriWizard supports two deployment environments:

1. **Local Development** - Docker Compose based, for developers
2. **Production (Azure)** - Managed Azure services, for deployment

---

## Environment Comparison

| Component | Local Dev | Azure Production |
|-----------|-----------|------------------|
| **Orchestration** | Docker Compose | Azure Container Apps |
| **API Gateway** | Kong | Azure API Management |
| **Database** | PostgreSQL (Docker) | Azure DB for PostgreSQL Flexible |
| **Messaging** | RabbitMQ + NATS | Azure Service Bus |
| **IoT** | HiveMQ Cloud | Azure IoT Hub |
| **Email** | Mailhog | Azure Communication Services |
| **Secrets** | `.env` files | Azure Key Vault |
| **Observability** | Console logs | Azure Monitor + App Insights |
| **Container Registry** | Local Docker | Azure Container Registry |
| **CDN** | N/A | Azure Front Door |
| **Storage** | Local volume | Azure Blob Storage |

---

## Local Development Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Developer Laptop                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │   IAM    │  │Hardware  │  │Analytics │  │ Weather  │   │
│  │ Service  │  │ Service  │  │ Service  │  │ Service  │   │
│  │ :8086    │  │ :8087    │  │ :8088    │  │ :8089    │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
│       │             │             │             │          │
│  ┌────┴─────────────┴─────────────┴─────────────┴────┐    │
│  │                    Kong Gateway (:8000)            │    │
│  └────────────────────┬───────────────────────────────┘    │
│                       │                                   │
│  ┌────────────────────┴───────────────────────────┐     │
│  │              Next.js Frontend (:3000)           │     │
│  └─────────────────────────────────────────────────┘     │
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                │
│  │PostgreSQL│  │ RabbitMQ │  │  NATS    │                │
│  │ :5432   │  │ :5672    │  │ :4222    │                │
│  └──────────┘  └──────────┘  └──────────┘                │
│                                                             │
│  ┌──────────┐  ┌──────────┐                              │
│  │ Mailhog  │  │ HiveMQ   │                              │
│  │ :1025   │  │ Cloud    │                              │
│  └──────────┘  └──────────┘                              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
         │                    │
         │   Docker Compose   │
         └──────────────────┘
```

**Ports (8XXX range):**

| Service | Port | Internal Port |
|---------|------|---------------|
| Kong Gateway | 8000 | 8000 |
| IAM Service | 8081 | 8086 |
| Hardware Service | 8082 | 8087 |
| Analytics Service | 8083 | 8088 |
| Weather Service | 8085 | 8089 |
| Notification Service | 8096 | 8091 |
| PostgreSQL | 8091 | 5432 |
| RabbitMQ | 8092 | 5672 |
| RabbitMQ Mgmt | 8093 | 15672 |
| NATS | 8094 | 4222 |
| NATS Monitor | 8095 | 8222 |
| Mailhog SMTP | 8097 | 1025 |
| Mailhog UI | 8098 | 8025 |
| Swagger UI | 8090 | 8080 |
| Next.js | 3000 | 3000 |

---

## Azure Production Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Azure Cloud                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                      CDN   │
│                                                          ┌──────────────┐ │
│                                                          │Front Door   │ │
│                                                          │:443 (HTTPS) │ │
│                                                          └──────┬───────┘ │
│                                                                 │        │
│  ┌─────────────────────────────────────────────────────────────────┐          │        │
│  │              Azure API Management                     │          │        │
│  │                   :443                            │◄─────────┘        │
│  │  JWT Validation • Rate Limiting • CORS            │                   │
│  └────────────────────────┬────────────────────────┘                   │
│                           │                                             │
│        ┌──────────────────┼──────────────────┐                          │
│        │                  │                  │                          │
│  ┌─────┴─────┐      ┌────┴────┐      ┌────┴────┐                      │
│  │  IAM     │      │Hardware  │      │Analytics │   ... (all services)        │
│  │ Container│      │ Container│      │ Container│                       │
│  │  Apps    │      │  Apps    │      │  Apps    │                       │
│  └─────┬─────┘      └────┬─────┘      └────┬─────┘                       │
│        │                 │                 │                               │
│        └────────────────┼────────────────┘                               │
│                         │                                               │
│  ┌─────────────────────┴───────────────────────┐                        │
│  │         Azure Container Apps                │                        │
│  │            (ACA Environment)                │                        │
│  │  • Internal networking                      │                        │
│  │  • VNET integration                         │                        │
│  └────────────────────────────────────────────┘                        │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────────┐  │
│  │                    Azure Services                                │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │  │
│  │  │PostgreSQL   │  │Service Bus │  │   IoT Hub              │  │  │
│  │  │Flexible    │  │ (Queues)   │  │   (MQTT)              │  │  │
│  │  │            │  │           │  │                       │  │  │
│  │  └─────────────┘  └─────────────┘  └─────────────────────────┘  │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │  │
│  │  │Key Vault    │  │App Insights│  │   Blob Storage        │  │  │
│  │  │(Secrets)   │  │(Monitoring)│  │   (Files)            │  │  │
│  │  └─────────────┘  └─────────────┘  └─────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌──────────┐  ┌────────────┐  ┌─────────────────────────┐              │
│  │ IoT Edge │  │ Greenhouse │  │  Azure Communication  │              │
│  │ Devices │  │  Sensors  │  │  Services (Email)    │              │
│  └──────────┘  └────────────┘  └─────────────────────────┘              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Mapping

| AgriWizard Component | Local Dev | Azure Production |
|---------------------|-----------|-----------------|
| **Orchestration** | docker-compose.yml | Azure Container Apps |
| **API Gateway** | Kong (docker) | Azure API Management |
| **IAM Service** | Go/Gin (docker) | Container Apps |
| **Hardware Service** | Go/Gin (docker) | Container Apps |
| **Analytics Service** | Go/Gin (docker) | Container Apps |
| **Weather Service** | Go/Gin (docker) | Container Apps |
| **Notification Service** | Go/Gin (docker) | Container Apps |
| **Database** | PostgreSQL (docker) | Azure DB for PostgreSQL |
| **Message Queue** | RabbitMQ | Azure Service Bus |
| **Event Streaming** | NATS | Azure Event Grid |
| **IoT Protocol** | HiveMQ Cloud | Azure IoT Hub |
| **Email** | Mailhog | Azure Communication Services |
| **Secrets** | .env files | Azure Key Vault |
| **Monitoring** | Console/Docker logs | Azure Monitor + App Insights |
| **Container Registry** | Local Docker | Azure Container Registry |
| **Frontend** | Next.js (localhost) | Static Web App / Container Apps |
| **CDN** | N/A | Azure Front Door |
| **File Storage** | Local volume | Azure Blob Storage |

---

## Migration Strategy

### Phase 1: Dual Environment Setup

1. Keep existing docker-compose.yml for local development
2. Create new Azure infrastructure code
3. Ensure services work with both environments via environment variables

### Phase 2: Azure Services Provisioning

1. Deploy Azure infrastructure (IaC)
2. Configure networking and security
3. Set up CI/CD pipeline

### Phase 3: Migration

1. Migrate database schema
2. Switch IoT to Azure IoT Hub
3. Migrate messaging to Service Bus
4. Deploy services to Azure Container Apps

### Phase 4: Cutover

1. Update DNS / Front Door
2. Monitor metrics
3. Rollback plan if needed

---

## Environment Variables

### Local Development (.env)

```bash
# Database
DB_HOST=postgres
DB_PORT=5432
DB_USER=agriwizard
DB_PASSWORD=agriwizard_secret
DB_NAME=agriwizard
DB_SSLMODE=disable

# JWT
JWT_SECRET=dev-secret-key
JWT_ISSUER=agriwizard-iam
JWT_TTL_HOURS=24

# Messaging
RABBITMQ_HOST=rabbitmq
RABBITMQ_PORT=5672
NATS_URL=nats://nats:4222

# IoT
MQTT_BROKER=ssl://xxxx.hivemq.cloud:8883
MQTT_USERNAME=
MQTT_PASSWORD=

# Services (internal URLs)
IAM_SERVICE_URL=http://iam-service:8086
HARDWARE_SERVICE_URL=http://hardware-service:8087
ANALYTICS_SERVICE_URL=http://analytics-service:8088
WEATHER_SERVICE_URL=http://weather-service:8089
NOTIFICATION_SERVICE_URL=http://notification-service:8091

# Weather
USE_MOCK=true

# Email
SMTP_HOST=mailhog
SMTP_PORT=1025
```

### Azure Production (Key Vault references)

```bash
# Database
DB_HOST=postgres-server.postgres.database.azure.com
DB_PORT=5432
DB_USER=agriwizard@server-name
DB_PASSWORD=@KeyVaultSecret
DB_NAME=agriwizard
DB_SSLMODE=require

# JWT
JWT_SECRET=@KeyVaultSecret
JWT_ISSUER=agriwizard-iam
JWT_TTL_HOURS=24

# Messaging
SERVICE_BUS_CONNECTION=@KeyVaultSecret

# IoT
IOT_HUB_CONNECTION=@KeyVaultSecret

# Services
IAM_SERVICE_URL=http://iam-service.internal.aca
# ... etc

# Azure
APPLICATIONINSIGHTS_CONNECTION_STRING=@KeyVaultSecret
AZURE_STORAGE_CONNECTION_STRING=@KeyVaultSecret
```

---

## Why This Architecture

### Local Development

- **Docker Compose**: Industry standard, works everywhere
- **Kong**: Easy to configure, familiar to developers
- **RabbitMQ/NATS**: Well-supported, easy to debug
- **HiveMQ Cloud**: Free tier, minimal setup

### Azure Production

- **Container Apps**: Serverless, cost-effective, Kubernetes-underlying
- **API Management**: Enterprise features, security, developer portal
- **PostgreSQL Flexible**: Managed, high availability, scaling
- **Service Bus**: Enterprise messaging, dead-letter queues
- **IoT Hub**: Device management, offline support, DPS
- **Key Vault**: Enterprise secrets management
- **Application Insights**: Full observability stack
- **Front Door**: Global CDN, WAF, SSL termination