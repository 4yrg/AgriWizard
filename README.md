# AgriWizard — Smart Greenhouse Management System

A secure, cloud-native microservice backend for intelligent greenhouse automation. Built with **Go + Gin**, deployed via **Docker/Traefik**, and hardened with **DevSecOps** practices.

---

## Architecture Overview

```
                        ┌─────────────────────────────────────────────────────────┐
                        │              Traefik API Gateway  :8080                  │
                        │         Path-based Routing · CORS · EntryPoint           │
                        └──────────┬────────────┬─────────────┬───────────────────┘
                                   │            │             │            │
                    ┌──────────────▼──┐  ┌──────▼──────┐  ┌──▼──────────┐  ┌──────▼──────────┐
                    │  IAM Service    │  │  Hardware   │  │  Analytics  │  │  Weather        │
                    │    :8081        │  │  Service    │  │  Service    │  │  Service        │
                    │                 │  │   :8082     │  │   :8083     │  │   :8084         │
                    │ · Register/Login│  │             │  │             │  │                 │
                    │ · JWT Issuance  │  │ · Sensors   │  │ · Thresholds│  │ · OWM / Mock   │
                    │ · RBAC (Admin/  │  │ · Equipment │  │ · Rules     │  │ · Forecast      │
                    │   Agromist)     │  │ · MQTT Mgmt │  │ · Decisions │  │ · Scale Factor  │
                    │ · Introspect    │  │ · Telemetry │  │ · Summaries │  │ · Alerts        │
                    └──────────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────────────────┘
                               │                │                 │
                    ┌──────────▼────────────────▼─────────────────▼──────────────┐
                    │                    PostgreSQL  :5432                         │
                    │         iam.*   |   hardware.*   |   analytics.*             │
                    └───────────────────────────────────────────────────────────-─┘
                                                │
                    ┌───────────────────────────▼──────────────────────────────────┐
                    │               HiveMQ Cloud Cluster (external)                 │
                    │   agriwizard/sensor/{serial}/telemetry                        │
                    │   agriwizard/equipment/{serial}/command                       │
                    └───────────────────────────────────────────────────────────────┘
```

### Service Ports

| Service | Port | Description |
|---------|------|-------------|
| Traefik Gateway | **8080** | Single public entry point |
| IAM Service | 8081 | Auth & RBAC |
| Hardware Service | 8082 | IoT device management |
| Analytics Service | 8083 | Threshold logic & decisions |
| Weather Service | 8084 | Weather intelligence |
| PostgreSQL | 5432 | Shared DB (separate schemas) |
| HiveMQ Cloud MQTT | external (typically 8883 TLS) | IoT message broker |

*Direct service port is 8084 (gateway entry remains 8080).

---

## Quick Start

### Prerequisites
- Docker 24+ and Docker Compose v2
- Git

### 1. Clone and configure
```bash
git clone https://github.com/your-org/agriwizard.git
cd agriwizard
cp .env.example .env
# Edit .env — set MQTT_BROKER/MQTT_USERNAME/MQTT_PASSWORD and JWT_SECRET
```

### 2. Build and run
```bash
docker compose up --build -d
```

### 3. Verify health
```bash
curl http://localhost:8081/health   # IAM
curl http://localhost:8082/health   # Hardware
curl http://localhost:8083/health   # Analytics
curl http://localhost:8084/health   # Weather
```

### 4. First API call — register and login
```bash
# Register a user
curl -X POST http://localhost:8080/api/v1/iam/register \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@farm.lk","password":"Passw0rd!","full_name":"Admin User","role":"Admin"}'

# Login and capture the token
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/iam/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@farm.lk","password":"Passw0rd!"}' | jq -r '.token')

echo "Token: $TOKEN"
```

### 5. Full end-to-end demo
```bash
# Define a parameter type
curl -s -X POST http://localhost:8080/api/v1/hardware/parameters \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"id":"soil_moisture_pct","unit":"%","description":"Volumetric soil moisture"}'

# Register a water pump
PUMP_ID=$(curl -s -X POST http://localhost:8080/api/v1/hardware/equipments \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"serial":"pump_main_01","name":"Main Water Pump","supported_operations":["ON","OFF","REVERSE"]}' | jq -r '.data.id')

# Provision a soil sensor
curl -s -X POST http://localhost:8080/api/v1/hardware/sensors \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"serial\":\"soil_probe_zone_a\",\"name\":\"Zone A Soil Probe\",\"parameter_ids\":[\"soil_moisture_pct\"]}"

# Set threshold (30-70% moisture)
THRESHOLD_ID=$(curl -s -X POST http://localhost:8080/api/v1/analytics/thresholds \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"parameter_id":"soil_moisture_pct","min_value":30,"max_value":70}' | jq -r '.data.id')

# Link pump to threshold via automation rule
curl -s -X POST http://localhost:8080/api/v1/analytics/rules \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"threshold_id\":\"$THRESHOLD_ID\",\"equipment_id\":\"$PUMP_ID\",\"low_action\":\"ON\",\"high_action\":\"OFF\"}"

# Simulate low moisture telemetry — should trigger pump ON
curl -s -X POST http://localhost:8080/api/v1/hardware/telemetry \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"sensor_id\":\"test-sensor\",\"readings\":[{\"parameter_id\":\"soil_moisture_pct\",\"value\":18.5}]}"

# Check the decision table
curl -s http://localhost:8080/api/v1/analytics/decisions/summary \
  -H "Authorization: Bearer $TOKEN" | jq .

# Get weather-based irrigation scale factor
curl -s http://localhost:8080/api/v1/weather/recommendations \
  -H "Authorization: Bearer $TOKEN" | jq .
```

---

## Project Structure

```
agriwizard/
├── go.work                          # Go workspace (monorepo)
├── docker-compose.yml               # Full stack local deployment
├── swagger.yaml                     # OpenAPI 3.0 specification
├── sonar-project.properties         # SonarCloud SAST config
├── .env.example                     # Environment variable template
├── .gitignore
│
├── services/
│   ├── iam-service/
│   │   ├── main.go                  # Server setup, DB, migrations
│   │   ├── models.go                # User, Claims, DTOs
│   │   ├── handlers.go              # Register, Login, Introspect, Profile
│   │   ├── go.mod
│   │   └── Dockerfile
│   │
│   ├── hardware-service/
│   │   ├── main.go                  # Server, MQTT connect, subscription restore
│   │   ├── models.go                # Equipment, Sensor, Parameter, Telemetry
│   │   ├── handlers.go              # CRUD + DispatchControl + MQTT callbacks
│   │   ├── go.mod
│   │   └── Dockerfile
│   │
│   ├── analytics-service/
│   │   ├── main.go                  # Server setup
│   │   ├── models.go                # Threshold, Rule, Summary, Decision
│   │   ├── handlers.go              # Threshold CRUD, Rules, Ingest, Summary
│   │   ├── go.mod
│   │   └── Dockerfile
│   │
│   └── weather-service/
│       ├── main.go                  # Server setup, config
│       ├── models.go                # WeatherCondition, Forecast, Alert, Recommendation
│       ├── handlers.go              # Current, Forecast, Alerts, Recommendations
│       ├── go.mod
│       └── Dockerfile
│
└── .github/
    └── workflows/
        └── ci-cd.yml                # GitHub Actions: SAST → Build → Push → Deploy
```

---

## API Reference

Full OpenAPI spec is in `swagger.yaml`. Import it into [Swagger Editor](https://editor.swagger.io) or Postman.

### Key Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/v1/iam/register` | ✗ | Register user |
| POST | `/api/v1/iam/login` | ✗ | Get JWT token |
| GET | `/api/v1/iam/introspect` | Bearer | Validate token |
| POST | `/api/v1/hardware/equipments` | Bearer | Register equipment |
| GET | `/api/v1/hardware/equipments` | Bearer | List equipment |
| POST | `/api/v1/hardware/control/{id}` | Bearer | Dispatch MQTT command |
| POST | `/api/v1/hardware/sensors` | Bearer | Provision sensor |
| GET | `/api/v1/hardware/sensors` | Bearer | List sensors |
| POST | `/api/v1/hardware/parameters` | Bearer | Define parameter type |
| POST | `/api/v1/hardware/telemetry` | Bearer | REST telemetry ingest |
| POST | `/api/v1/analytics/thresholds` | Bearer | Set threshold range |
| GET | `/api/v1/analytics/thresholds/{id}` | Bearer | Get threshold |
| POST | `/api/v1/analytics/rules` | Bearer | Create automation rule |
| GET | `/api/v1/analytics/rules/{parameterId}` | Bearer | Get rules |
| GET | `/api/v1/analytics/decisions/summary` | Bearer | Decision table |
| POST | `/api/v1/analytics/ingest` | Bearer | Ingest & evaluate telemetry |
| GET | `/api/v1/analytics/summaries` | Bearer | Daily aggregated stats |
| GET | `/api/v1/weather/current` | Bearer | Live weather |
| GET | `/api/v1/weather/forecast` | Bearer | 24h forecast |
| GET | `/api/v1/weather/alerts` | Bearer | Active alerts |
| GET | `/api/v1/weather/recommendations` | Bearer | Irrigation scale factor |

---

## MQTT Topics

| Topic Pattern | Direction | Description |
|---------------|-----------|-------------|
| `agriwizard/sensor/{sensor_id}/telemetry` | Device → Service | Sensor data ingestion |
| `agriwizard/equipment/{equipment_id}/command` | Service → Device | Control commands |
| `agriwizard/equipment/{equipment_id}/command/status` | Device → Service | Status acknowledgements |

### MQTT Telemetry Payload Example
```json
{
  "sensor_id": "uuid-of-sensor",
  "readings": [
    { "parameter_id": "soil_moisture_pct", "value": 34.2 },
    { "parameter_id": "soil_temp_c", "value": 24.1 }
  ],
  "timestamp": "2026-03-21T10:30:00Z"
}
```

---

## Security (DevSecOps)

### Authentication & Authorization
- **JWT HS256** tokens issued by IAM, validated by each microservice middleware
- **RBAC** — `Admin` role required for manual override; `Agromist` for standard ops
- **Principle of Least Privilege** — each service only reads/writes its own DB schema
- Internal service calls use `X-Internal-Service` header (no JWT required for service-to-service)

### DevSecOps Pipeline
1. **SonarCloud** — SAST static analysis on every PR
2. **Snyk** — dependency vulnerability scanning
3. **Trivy** — filesystem + container image CVE scanning
4. **GitHub Secrets** — no credentials in source code

---

## Weather Service — Live vs Mock

The weather service ships in **mock mode** by default (no API key needed).

To switch to live OpenWeatherMap data:
1. Get a free API key at https://openweathermap.org/api
2. In `docker-compose.yml`, set:
   ```yaml
   USE_MOCK: "false"
   OWM_API_KEY: "your-api-key-here"
   ```

The irrigation scale factor logic:

| Condition | Scale | Action |
|-----------|-------|--------|
| Rain ≥ 90% chance | **0.0** | Skip irrigation entirely |
| Rain ≥ 60% chance | **0.5** | Halve irrigation |
| Temp > 38°C | **1.4** | Irrigate 40% more |
| Temp > 35°C | **1.2** | Irrigate 20% more |
| Temp < 20°C | **0.8** | Irrigate 20% less |
| Normal | **1.0** | Standard irrigation |

---

## Database Schema

Each service uses an isolated PostgreSQL schema:

```
iam.users
hardware.equipments, hardware.sensors, hardware.parameters, hardware.raw_sensor_data
analytics.thresholds, analytics.automation_rules, analytics.daily_summaries
```

Migrations run automatically on service startup.

---

## Development

### Running a single service locally
```bash
cd services/iam-service
DB_HOST=localhost JWT_SECRET=dev-secret go run .
```

### Running all services in Docker
```bash
docker compose up --build
```

### Rebuilding a single service
```bash
docker compose build hardware-service
docker compose up -d hardware-service
```

### Viewing logs
```bash
docker compose logs -f analytics-service
```

---

## 🚀 Deployment (Azure Container Apps)

AgriWizard uses GitHub Actions for CI/CD with Azure Container Apps. Deployment is based on **publish profile authentication** (no Service Principals required).

### Prerequisites

1. **Azure Subscription** with contributor access
2. **GitHub repository** with secrets configured

### 1. Infrastructure Setup (One-Time)

Run the bootstrap script to create Azure resources:

```bash
# Copy and configure environment
cp infrastructure/aca/aca.env.example infrastructure/aca/aca.env
# Edit aca.env with your values

# Run bootstrap
./scripts/bootstrap-azure.sh
```

This creates:
- Resource Group
- Azure Container Registry (ACR)
- Container Apps Environment
- Log Analytics & Application Insights

### 2. Configure GitHub Secrets

Required secrets in GitHub repository settings:

| Secret | Description | How to Get |
|--------|------------|------------|
| `AZURE_CONTAINERAPP_PUBLISH_PROFILE` | Azure deployment auth | Azure Portal → Container App → Publishing profile |
| `ACR_USERNAME` | ACR admin username | Azure Portal → your ACR → Access keys |
| `ACR_PASSWORD` | ACR admin password | Azure Portal → your ACR → Access keys |
| `SONAR_TOKEN` | SonarCloud token | sonarcloud.io → My Account → Security |

### 3. CI/CD Flow

| Event | Pipeline | Actions |
|-------|---------|---------|
| PR to main | **CI** | Lint, build, security scan |
| Push to main | **CD** | Build → Push to ACR → Deploy to ACA |

### 4. Manual Deployment

```bash
# Build and push a service
docker build -t agriwizard.azurecr.io/agriwizard-iam-service:latest ./services/iam-service
docker push agriwizard.azurecr.io/agriwizard-iam-service:latest

# Deploy to Container Apps
az containerapp update \
  --name iam-service \
  --resource-group agriwizard-rg \
  --image agriwizard.azurecr.io/agriwizard-iam-service:latest
```

---

## 🧱 Infrastructure Setup

### Bootstrap Script

The `scripts/bootstrap-azure.sh` script provisions all Azure resources idempotently:

```bash
./scripts/bootstrap-azure.sh
```

**Configuration:** Edit `infrastructure/aca/aca.env`:

```bash
SUBSCRIPTION_ID=<your-subscription-id>
RESOURCE_GROUP=agriwizard-rg
LOCATION=centralindia
ACA_ENV_NAME=agriwizard-aca-env
ACR_NAME=agriwizardacr
LOG_ANALYTICS_NAME=agriwizard-law
APP_INSIGHTS_NAME=agriwizard-appinsights
JWT_SECRET=<your-32-char-min-secret>
```

**Required Providers:** The script auto-registers:
- Microsoft.App
- Microsoft.OperationalInsights
- Microsoft.Insights
- Microsoft.ContainerRegistry

---

## 🔐 Required GitHub Secrets

| Secret | Required | Description |
|--------|----------|------------|
| `AZURE_CREDENTIALS` | Yes | Azure service principal JSON (see format below) |
| `ACR_USERNAME` | Yes | ACR admin username |
| `ACR_PASSWORD` | Yes | ACR admin password |
| `SONAR_TOKEN` | No | SonarCloud authentication |

### AZURE_CREDENTIALS Format

Create a JSON with these values:
```json
{
  "clientId": "your-app-client-id",
  "clientSecret": "your-client-secret",
  "subscriptionId": "71dc1447-483b-4aa3-b549-021a60ec7241",
  "tenantId": "44e3cf94-19c9-4e32-96c3-14f5bf01391a"
}
```

### How to Create Service Principal

1. Go to **Azure Portal** → **Microsoft Entra ID** → **App registrations**
2. Click **New registration** → Name: `AgriWizard-GitHub`
3. Note the **Application (client) ID**
4. Go to **Certificates & secrets** → **New client secret**
5. Note the **Value** (this is clientSecret)
6. Go to **Enterprise applications** → find your app
7. Assign **Contributor** role to: `/subscriptions/71dc1447-483b-4aa3-b549-021a60ec7241/resourceGroups/agriwizard-rg`

---

## ⚠️ Why Terraform Was Removed

**Reason:** Terraform configuration relied on Azure Service Principals (Azure AD) for authentication, which were no longer available.

### Before (Terraform)
- `AZURE_CLIENT_ID` + `AZURE_CLIENT_SECRET` + `AZURE_TENANT_ID`
- Complex provider configuration
- State management required
- Drift detection overhead

### After (Script + GitHub Actions)
- `AZURE_CONTAINERAPP_PUBLISH_PROFILE` only
- Idempotent bash script for infra
- No state to manage
- Simpler CI/CD pipeline

For production-grade infrastructure-as-code, consider using Bicep or Pulumi (both support publish profile auth).

---

## 📚 Documentation

Detailed documentation is available in the `docs/` folder:

| Document | Description |
|----------|------------|
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Step-by-step deployment guide for Azure Container Apps |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Detailed architecture and service design |
| [docs/SECRETS.md](docs/SECRETS.md) | GitHub secrets configuration guide |

---

## 🐇 Messaging Architecture

AgriWizard uses RabbitMQ for inter-service messaging (replacing Azure Service Bus):

```
Hardware Service ──publish──▶ RabbitMQ ──consume──▶ Analytics Service
                              │
                              └──consume──▶ Notification Service
```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `RABBITMQ_URL` | RabbitMQ connection URL (e.g., `amqp://guest:guest@rabbitmq:5672`) |
| `RABBITMQ_QUEUE` | Queue name for telemetry (`telemetry`) |

### IoT Messaging

HiveMQ Cloud is used for IoT device communication:

```
IoT Devices ──MQTT──▶ HiveMQ Cloud ──subscribe──▶ Hardware Service
```

---

## 🚀 Auto-Deploy

The CD pipeline automatically deploys to Azure Container Apps when:

1. Code is pushed to `main` branch
2. A version tag is created (e.g., `v1.0.0`)

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for detailed deployment instructions.
