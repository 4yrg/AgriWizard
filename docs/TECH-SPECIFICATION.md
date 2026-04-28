# AgriWizard Technical Specification

## Project Overview

AgriWizard is a cloud-native microservice backend for intelligent greenhouse automation. It provides:

- IoT device management (sensors and equipment)
- Real-time sensor telemetry monitoring
- Automated equipment control based on configurable thresholds
- Weather-integrated irrigation recommendations
- Notification system for alerts

**Type**: Go-based microservice architecture with Docker deployment
**Repository**: `/home/dasun/Projects/SLIIT/CTSE/AgriWizard`

---

## Architecture

### Microservices

| Service | External Port | Internal Port | Description |
|---------|--------------|---------------|-------------|
| **IAM Service** | 8081 | 8086 | Identity & Access Management, JWT |
| **Hardware Service** | 8082 | 8087 | IoT device management, MQTT |
| **Analytics Service** | 8083 | 8088 | Threshold rules, automation |
| **Weather Service** | 8085 | 8089 | Weather intelligence |
| **Notification Service** | 8096 | 8091 | Email/notification handling |
| **Kong Gateway** | 8000 | 8000 | API Gateway |

### Technology Stack

| Component | Technology |
|-----------|------------|
| **Language** | Go 1.26+ |
| **Web Framework** | Gin |
| **Database** | PostgreSQL (Aiven cloud) |
| **API Gateway** | Kong 3.4 |
| **Message Queues** | RabbitMQ 3.12, NATS 2.10 |
| **IoT Protocol** | MQTT (HiveMQ Cloud) |
| **Frontend** | Next.js 16, React 19, Tailwind CSS 4 |
| **Deployment** | Docker, Azure Container Apps |

### Service Communication

| Path | Protocol | Description |
|------|----------|-------------|
| Client -> Gateway | HTTP/REST | All public API via Kong |
| Gateway -> Services | HTTP | Kong routes to upstream services |
| Hardware -> Analytics | RabbitMQ AMQP | Telemetry ingestion |
| Hardware -> IoT Devices | MQTT | HiveMQ Cloud |
| Analytics -> Hardware | RabbitMQ | Trigger equipment actions |
| Notification -> NATS | NATS | Event-driven notifications |

---

## Infrastructure

### API Gateway (Kong)

**Config**: `infrastructure/kong/kong.yml`

- JWT validation (HS256)
- Path-based routing
- CORS support
- Rate limiting (120/min, 2000/hour)
- Declarative configuration (DB-less)

**Routes**:
```
/api/v1/iam         -> iam-service:8086
/api/v1/hardware    -> hardware-service:8087
/api/v1/analytics  -> analytics-service:8088
/api/v1/weather     -> weather-service:8089
/api/v1/notifications -> notification-service:8091
```

### Database (PostgreSQL)

**Provider**: Aiven PostgreSQL
**Host**: `gradeloop-gradeloop-project.k.aivencloud.com:21005`
**SSL**: Enabled

| Schema | Service | Tables |
|--------|---------|--------|
| `iam` | IAM | `users` |
| `hardware` | Hardware | `equipments`, `sensors`, `parameters`, `raw_sensor_data` |
| `analytics` | Analytics | `thresholds`, `automation_rules`, `daily_summaries` |
| `notifications` | Notification | `notifications`, `templates` |

### External Integrations

| Service | Provider | Config |
|---------|----------|--------|
| **MQTT Broker** | HiveMQ Cloud | `ssl://0844c36e03374e7682f81036bb673d45.s1.eu.hivemq.cloud:8883` |
| **Weather Data** | OpenWeatherMap | Mock mode available |

---

## Core Components

### IAM Service

**Location**: `services/iam-service/`

- User registration with roles (`Admin`, `Agromist`)
- JWT token generation (HS256, 24h TTL)
- Token introspection

### Hardware Service

**Location**: `services/hardware-service/`

- Equipment CRUD
- Sensor CRUD
- MQTT integration for device communication

**MQTT Topics**:
```
agriwizard/sensor/{sensor_id}/telemetry
agriwizard/equipment/{equipment_id}/command
agriwizard/equipment/{equipment_id}/command/status
```

### Analytics Service

**Location**: `services/analytics-service/`

- Threshold management per parameter
- Automation rules
- Decision table generation
- Daily summary aggregation

### Weather Service

**Location**: `services/weather-service/`

- Current weather (live or mock)
- 24-hour forecast
- Weather alerts
- Irrigation scale factor

**Irrigation Scale Logic**:
| Condition | Scale Factor |
|-----------|-------------|
| Rain >= 90% | 0.0 (skip) |
| Rain >= 60% | 0.5 (halve) |
| Temp > 38°C | 1.4 (+40%) |
| Temp > 35°C | 1.2 (+20%) |
| Default | 1.0 |

### Notification Service

**Location**: `services/notification-service/`

- Email notifications via SMTP (Mailhog for dev)
- Template-based messaging
- NATS event subscription

---

## Configuration

**Files**:
- `.env` - Environment variables
- `docker-compose.yml` - Service orchestration
- `infrastructure/kong/kong.yml` - Gateway config

**Key Environment Variables**:
```
DB_HOST, DB_PORT, DB_USER, DB_PASSWORD
JWT_SECRET, JWT_TTL_HOURS
MQTT_BROKER, MQTT_USERNAME, MQTT_PASSWORD
USE_MOCK, OWM_API_KEY
```

---

## Directory Structure

```
/
├── client/                 # Next.js frontend
├── docs/                   # Documentation
├── infrastructure/
│   └── kong/              # Kong gateway config
├── services/
│   ├── iam-service/        # Identity & Access
│   ├── hardware-service/  # IoT devices
│   ├── analytics-service/ # Automation
│   ├── weather-service/   # Weather data
│   └── notification-service/
├── swagger.yaml           # OpenAPI spec
├── docker-compose.yml     # Orchestration
└── .env                # Configuration
```

---

## API Endpoints

### IAM (`/api/v1/iam`)
- `POST /auth/register` - User registration
- `POST /auth/login` - Login
- `POST /auth/introspect` - Token validation

### Hardware (`/api/v1/hardware`)
- `GET/POST /equipments` - Equipment CRUD
- `GET/POST /sensors` - Sensor CRUD
- `GET/POST /parameters` - Parameter types

### Analytics (`/api/v1/analytics`)
- `GET/POST /thresholds` - Threshold CRUD
- `GET/POST /rules` - Automation rules
- `GET /decisions` - Decision tables
- `GET /summaries` - Daily summaries

### Weather (`/api/v1/weather`)
- `GET /current` - Current conditions
- `GET /forecast` - 24h forecast
- `GET /recommendations` - Irrigation suggestions

### Notifications (`/api/v1/notifications`)
- `GET/POST /notifications` - Send/view notifications
- `GET/POST /templates` - Email templates