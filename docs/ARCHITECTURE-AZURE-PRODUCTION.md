# AgriWizard — Azure Production Architecture

## Component Mapping

| AgriWizard Component | Local Dev | Azure Production | Reason |
|---------------------|-----------|-----------------|--------|
| **Orchestration** | Docker Compose | Azure Container Apps | Serverless, scale-to-zero, pay-per-use |
| **API Gateway** | Kong | Azure API Management | Enterprise security, developer portal, rate limiting |
| **IAM Service** | Go/Gin (container) | Container Apps | Same Go service, managed |
| **Hardware Service** | Go/Gin (container) | Container Apps | Same Go service, managed |
| **Analytics Service** | Go/Gin (container) | Container Apps | Same Go service, managed |
| **Weather Service** | Go/Gin (container) | Container Apps | Same Go service, managed |
| **Notification Service** | Go/Gin (container) | Container Apps | Same Go service, managed |
| **Database** | PostgreSQL (docker) | Azure DB for PostgreSQL Flexible | Managed,HA,scaling |
| **Messaging** | RabbitMQ | Azure Service Bus | Enterprise queues, dead-letter |
| **Event Streaming** | NATS | Azure Event Grid | Event-driven, serverless |
| **IoT Protocol** | HiveMQ Cloud | Azure IoT Hub | Device management,DPS,offline |
| **Email** | Mailhog | Azure Communication Services | Enterprise email API |
| **Secrets** | .env files | Azure Key Vault | Enterprise secrets mgmt |
| **Monitoring** | Docker logs | Azure Monitor + App Insights | Full observability |
| **CDN** | N/A | Azure Front Door | Global CDN,WAF,SSL |
| **Storage** | Local volume | Azure Blob Storage | Object storage |

---

## Azure Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Azure Cloud                                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────┐                                          │
│  │    Azure Front Door     │ :443 (HTTPS)                               │
│  │    (CDN + WAF)        │                                          │
│  └───────────┬─────────────┘                                          │
│              │                                                       │
│              ▼                                                       │
│  ┌─────────────────────────┐                                          │
│  │  Azure API Management │ :443                                       │
│  │  • JWT Validation    │                                          │
│  │  • Rate Limiting    │                                          │
│  │  • CORS            │                                          │
│  │  • OAuth           │                                          │
│  └───────────┬─────────────┘                                          │
│              │                                                       │
│    ┌───────┴───────┬──────────┬──────────┬──────────┐                  │
│    ▼               ▼          ▼          ▼          ▼                      │
│ ┌──────┐    ┌────────┐ ┌───────┐ ┌───────┐ ┌──────────┐         │
│ │ IAM  │    │Hardware│ │Analytics│ │ Weather│ │ Notif.  │         │
│ │ Apps │    │  Apps  │ │  Apps  │ │  Apps │ │   Apps   │         │
│ └──┬───┘    └───┬────┘ └──┬────┘ └──┬────┘ └──┬───────┘         │
│    │            │          │          │          │                    │
│    └────────────┴─────────┴──────────┴──────────┘                │
│                         │                                             │
│    ┌────────────────────┴──────────────────────────────────┐       │
│    │         Azure Container Apps Environment (ACA)            │       │
│    │    • Internal networking (private endpoints)               │       │
│    │    • VNET integration                                    │       │
│    │    • Zone redundancy                                   │       │
│    └──────────────────────────────────────────────────────────┘       │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │                    Azure PaaS Services                           │  │
│  │ ┌──────────────┐  ┌─────────────┐  ┌────────────────────────┐  │  │
│  │ │ PostgreSQL   │  │Service Bus  │  │    IoT Hub             │  │  │
│  │ │ Flexible    │  │  (Queues)   │  │    (MQTT)             │  │  │
│  │ │ - HA         │  │ - Topics    │  │ - Device Provisioning │  │  │
│  │ │ - Auto-scale│  │ - DLQ       │  │ - Device Twins       │  │  │
│  │ │ - Backups   │  │ - Sessions  │  │ - Commands          │  │  │
│  │ └──────────────┘  └─────────────┘  └────────────────────────┘  │  │
│  │ ┌──────────────┐  ┌─────────────┐  ┌────────────────────────┐  │  │
│  │ │  Key Vault  │  │ App Insights│  │  Blob Storage      │  │  │
│  │ │ (Secrets)   │  │ (Monitoring)│  │   (Files/Backups)  │  │  │
│  │ └──────────────┘  └─────────────┘  └────────────────────────┘  │  │
│  │ ┌──────────────┐  ┌─────────────┐                            │  │
│  │ │  Front Door │  │ ACS Email   │                            │  │
│  │ └──────────────┘  └─────────────┘                            │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  ┌────���───────┐    ┌────────────┐    ┌─────────────────────────┐     │
│  │ IoT Edge   │    │Greenhouse │    │  External Systems      │     │
│  │ Devices   │    │ Sensors   │    │  • OpenWeatherMap       │     │
│  └────────────┘    └────────────┘    │  • HiveMQ Cloud (dev) │     │
│                                        └─────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Service Configuration

### Azure Container Apps

| Service | CPU | Memory | Min Replicas | Max Replicas | HTTP |
|---------|-----|-------|--------------|--------------|-----|
| **IAM** | 0.5 | 1Gi | 1 | 3 | /auth/* |
| **Hardware** | 1.0 | 2Gi | 1 | 5 | /hardware/* |
| **Analytics** | 1.0 | 2Gi | 1 | 5 | /analytics/* |
| **Weather** | 0.25 | 0.5Gi | 0 | 2 | /weather/* |
| **Notification** | 0.5 | 1Gi | 1 | 3 | /notifications/* |

### Azure Service Bus

| Queue/Topic | Type | Description |
|------------|------|-------------|
| `telemetry-ingest` | Queue | Incoming sensor data |
| `equipment-commands` | Queue | Outgoing commands |
| `notifications` | Topic | Notification events |
| `alerts` | Topic | Alert events |

### Azure IoT Hub

| Setting | Value |
|---------|-------|
| Tier | Standard (Free available) |
| Units | 1 |
| MQTT | 8883, 443 |
| AMQP | 5671, 5672 |
| Device Provisioning | Enabled |

---

## Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Virtual Network (10.0.0.0/16)            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Subnet: Container Apps (10.0.1.0/24)              │   │
│  │  - IAM Apps                                        │   │
│  │  - Hardware Apps                                   │   │
│  │  - Analytics Apps                                 │   │
│  │  - Weather Apps                                  │   │
│  │  - Notification Apps                           │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Subnet: Private Endpoints (10.0.2.0/24)           │   │
│  │  - PostgreSQL Private Link                        │   │
│  │  - Service Bus Private Link                      │   │
│  │  - Key Vault Private Link                        │   │
│  │  - Storage Private Link                       │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Subnet: API Management (10.0.3.0/24)              │   │
│  │  - APIM VNet injection                            │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Security Configuration

### Azure Key Vault Secrets

| Secret | Description |
|--------|-------------|
| `db-password` | PostgreSQL password |
| `jwt-secret` | JWT signing key |
| `iot-hub-connection` | IoT Hub connection string |
| `service-bus-connection` | Service Bus connection |
| `storage-connection` | Blob Storage connection |
| `smtp-password` | Email SMTP password |
| `apim-jwt-secret` | APIM JWT validation secret |

### Managed Identities

| Identity | Type | Purpose |
|----------|------|--------|
| `id-aca-terraform` | System | Infrastructure deployment |
| `id-apim` | System | APIM to access Key Vault |
| `id-container-apps` | System | Container Apps to access Azure services |

### TLS/SSL

| Component | Certificate |
|-----------|-------------|
| Front Door | App Service certificate (automated) |
| APIM | Built-in or App Service certificate |
| IoT Hub | Managed identity certificate |

---

## Environment-Specific Settings

### Development (.env.azure-dev)

```bash
# Azure
RESOURCE_GROUP=agriwizard-dev-rg
LOCATION=eastus
ACA_ENV_NAME=agriwizard-dev-aca
APIM_NAME=agriwizard-dev-apim

# Database
DB_SSLMODE=require

# Feature flags
USE_MOCK=false
GIN_MODE=release
```

### Production (.env.azure-prod)

```bash
# Azure
RESOURCE_GROUP=agriwizard-prod-rg
LOCATION=eastus
ACA_ENV_NAME=agriwizard-prod-aca
APIM_NAME=agriwizard-prod-apim

# Database
DB_SSLMODE=require

# Feature flags
USE_MOCK=false
GIN_MODE=release
```

---

## Migration Checklist

- [ ] Create Azure Resource Group
- [ ] Provision VNET and subnets
- [ ] Deploy Azure Database for PostgreSQL
- [ ] Configure Key Vault with secrets
- [ ] Create IoT Hub
- [ ] Create Service Bus namespace
- [ ] Set up Container Apps environment
- [ ] Deploy Container Apps
- [ ] Configure APIM
- [ ] Set up Front Door with WAF
- [ ] Configure monitoring (App Insights)
- [ ] Test internal communication
- [ ] Test external API access
- [ ] Set up CI/CD pipeline
- [ ] Configure backup and DR