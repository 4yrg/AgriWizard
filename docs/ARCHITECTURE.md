# AgriWizard - Implementation Documentation

## Table of Contents
1. [Project Overview](#project-overview)
2. [Folder Structure](#folder-structure)
3. [Service Details](#service-details)
4. [File Reference](#file-reference)

---

## Project Overview

**AgriWizard** is a cloud-native microservice backend for intelligent greenhouse automation. It provides a complete system for managing IoT devices, monitoring sensor data, automating equipment control based on thresholds, and integrating weather intelligence.

### Architecture Summary

```
                    ┌─────────────────────────────────────────────────────────┐
                    │              Traefik API Gateway  :8080                  │
                    │         Path-based Routing · CORS · EntryPoint           │
                    └──────────┬────────────┬─────────────┬───────────────────┘
                                │            │             │            │
            ┌──────────────────▼──┐  ┌──────▼──────┐  ┌──▼──────────┐  ┌──────▼──────────┐
            │  IAM Service       │  │  Hardware   │  │  Analytics  │  │  Weather        │
            │    :8081           │  │  Service    │  │  Service    │  │  Service        │
            │                    │  │   :8082     │  │   :8083     │  │   :8084         │
            │ · Register/Login    │  │             │  │             │  │                 │
            │ · JWT Issuance      │  │ · Sensors   │  │ · Thresholds│  │ · OWM / Mock   │
            │ · RBAC (Admin/      │  │ · Equipment │  │ · Rules     │  │ · Forecast      │
            │   Agromist)        │  │ · MQTT Mgmt │  │ · Decisions │  │ · Alerts        │
            │ · Introspect       │  │ · Telemetry │  │ · Summaries │  │ · Recommendations
            └─────────────────────┘  └─────────────┘  └─────────────┘  └─────────────────┘
                                │                │                 │
            ┌────────────────────▼────────────────▼─────────────────▼─────────────────┐
            │                    PostgreSQL  :5432                                 │
            │         iam.*   |   hardware.*   |   analytics.*  | notifications.*     │
            └───────────────────────────────────────────────────────────────────────────┘
                                                    │
            ┌───────────────────────────────────────▼──────────────────────────────┐
            │               HiveMQ Cloud Cluster (external)                         │
            │   agriwizard/sensor/{id}/telemetry                                    │
            │   agriwizard/equipment/{id}/command                                  │
            └───────────────────────────────────────────────────────────────────────┘
```

### Technology Stack

| Component | Technology |
|-----------|------------|
| Language | Go 1.26+ |
| Web Framework | Gin |
| Database | PostgreSQL |
| Message Queue | MQTT (HiveMQ), NATS |
| API Gateway | Traefik v3 |
| Containerization | Docker |

### Database Schemas

| Schema | Service | Tables |
|--------|---------|--------|
| `iam` | IAM Service | users |
| `hardware` | Hardware Service | equipments, sensors, parameters, raw_sensor_data |
| `analytics` | Analytics Service | thresholds, automation_rules, daily_summaries |
| `notifications` | Notification Service | notifications, templates |

---

## Folder Structure

```
AgriWizard/
├── services/                    # All microservice code
│   ├── iam-service/             # Identity & Access Management
│   ├── hardware-service/        # IoT device management
│   ├── analytics-service/       # Threshold rules & automation
│   ├── weather-service/         # Weather intelligence
│   └── notification-service/   # Email/notification handling
├── gateway/                     # Traefik configuration
│   ├── traefik.yml             # Traefik main config
│   └── routes.yml              # Route definitions
├── docker-compose.yml          # Full stack deployment
├── swagger.yaml                # OpenAPI 3.0 specification
├── go.work                     # Go workspace file
├── .env.example                # Environment template
├── .golangci.yml              # Linter configuration
└── .github/workflows/          # CI/CD pipelines
    └── devsecops.yml          # DevSecOps pipeline
```

---

## Service Details

### 1. IAM Service (Port 8081)

**Purpose**: Identity & Access Management - handles user registration, authentication, JWT token issuance, and role-based access control.

**Key Features**:
- User registration with role assignment (Admin/Agromist)
- JWT token generation and validation
- Token introspection endpoint for other services
- User profile management

**Database Schema** (`iam`):
```sql
CREATE TABLE iam.users (
    id            TEXT PRIMARY KEY,
    email         TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role          TEXT NOT NULL DEFAULT 'Agromist',
    full_name     TEXT NOT NULL,
    phone         TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

### 2. Hardware Service (Port 8082)

**Purpose**: IoT device management - manages sensors, equipment (actuators), MQTT connectivity, and telemetry ingestion.

**Key Features**:
- Sensor provisioning and management
- Equipment (actuator) registration and control
- MQTT message broker integration
- REST API for telemetry ingestion
- Real-time telemetry forwarding to Analytics service

**Database Schema** (`hardware`):
```sql
CREATE TABLE hardware.equipments (
    id             TEXT PRIMARY KEY,
    name           TEXT NOT NULL,
    operations     TEXT[] NOT NULL DEFAULT '{}',
    mqtt_topic     TEXT NOT NULL,
    api_url        TEXT,
    current_status TEXT NOT NULL DEFAULT 'OFF',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE hardware.sensors (
    id               TEXT PRIMARY KEY,
    name             TEXT NOT NULL,
    parameter_ids    TEXT[] NOT NULL DEFAULT '{}',
    mqtt_topic       TEXT NOT NULL,
    api_url          TEXT,
    update_frequency INT NOT NULL DEFAULT 60,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE hardware.parameters (
    id          TEXT PRIMARY KEY,
    unit        TEXT NOT NULL,
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE hardware.raw_sensor_data (
    id           SERIAL PRIMARY KEY,
    sensor_id    TEXT NOT NULL,
    parameter_id TEXT NOT NULL,
    value        DOUBLE PRECISION NOT NULL,
    timestamp    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

**MQTT Topics**:
- Subscribe: `agriwizard/sensor/{sensor_id}/telemetry` - Receive sensor data
- Publish: `agriwizard/equipment/{equipment_id}/command` - Send control commands
- Subscribe: `agriwizard/equipment/{equipment_id}/command/status` - Receive status updates

---

### 3. Analytics Service (Port 8083)

**Purpose**: Threshold-based automation logic - evaluates sensor data against thresholds and triggers equipment automation.

**Key Features**:
- Threshold definition and management
- Automation rules (threshold → equipment action mapping)
- Decision table generation
- Telemetry ingestion and processing
- Daily summary aggregation
- Weather-based scale factor for irrigation recommendations

**Database Schema** (`analytics`):
```sql
CREATE TABLE analytics.thresholds (
    id           TEXT PRIMARY KEY,
    parameter_id TEXT UNIQUE NOT NULL,
    min_value    DOUBLE PRECISION NOT NULL DEFAULT 0,
    max_value    DOUBLE PRECISION NOT NULL,
    is_enabled   BOOLEAN NOT NULL DEFAULT true,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE analytics.automation_rules (
    id           TEXT PRIMARY KEY,
    threshold_id TEXT NOT NULL REFERENCES analytics.thresholds(id) ON DELETE CASCADE,
    equipment_id TEXT NOT NULL,
    low_action   TEXT NOT NULL,
    high_action  TEXT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE analytics.daily_summaries (
    id           SERIAL PRIMARY KEY,
    parameter_id TEXT NOT NULL,
    avg_value    DOUBLE PRECISION NOT NULL,
    min_recorded DOUBLE PRECISION NOT NULL,
    max_recorded DOUBLE PRECISION NOT NULL,
    date         DATE NOT NULL,
    UNIQUE (parameter_id, date)
);
```

**Automation Logic**:
```
Reading Value < Min Threshold → Trigger "low_action"
Reading Value > Max Threshold → Trigger "high_action"
```

---

### 4. Weather Service (Port 8084)

**Purpose**: Weather intelligence - provides current conditions, forecasts, alerts, and irrigation recommendations.

**Key Features**:
- Current weather data (live OpenWeatherMap or mock)
- 24-hour forecast with precipitation probability
- Weather alerts for extreme conditions
- Irrigation scale factor calculation

**Irrigation Recommendation Logic**:
| Condition | Scale | Action |
|-----------|-------|--------|
| Rain ≥ 90% chance | **0.0** | Skip irrigation entirely |
| Rain ≥ 60% chance | **0.5** | Halve irrigation |
| Temp > 38°C | **1.4** | Irrigate 40% more |
| Temp > 35°C | **1.2** | Irrigate 20% more |
| Temp < 20°C | **0.8** | Irrigate 20% less |
| Normal | **1.0** | Standard irrigation |

---

### 5. Notification Service (Port 8085)

**Purpose**: Multi-channel notification delivery - handles email notifications with template support.

**Key Features**:
- Template-based notification rendering
- Multiple delivery channels (Email, extensible)
- NATS JetStream consumer for async processing
- Notification history and tracking

**Database Schema** (`notifications`):
```sql
CREATE TABLE notifications.templates (
    id               TEXT PRIMARY KEY,
    name             TEXT NOT NULL,
    channel          TEXT NOT NULL,
    subject_template TEXT NOT NULL DEFAULT '',
    body_template    TEXT NOT NULL DEFAULT '',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE notifications.notifications (
    id         TEXT PRIMARY KEY,
    channel    TEXT NOT NULL,
    recipient  TEXT NOT NULL,
    subject    TEXT NOT NULL DEFAULT '',
    body       TEXT NOT NULL DEFAULT '',
    status     TEXT NOT NULL DEFAULT 'pending',
    error_msg  TEXT DEFAULT '',
    metadata   JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sent_at    TIMESTAMPTZ
);
```

---

## File Reference

### Root Level Files

| File | Description |
|------|-------------|
| `docker-compose.yml` | Full stack Docker Compose configuration with all services, database, message queue, and gateway |
| `go.work` | Go workspace file defining all service modules |
| `swagger.yaml` | OpenAPI 3.0 specification for all REST endpoints |
| `.env.example` | Environment variable template |
| `.golangci.yml` | Go linter configuration |
| `sonar-project.properties` | SonarCloud analysis configuration |
| `DEPLOY_AZURE_CONTAINER_APPS.md` | Azure deployment documentation |
| `SETUP_SECRETS.md` | Secret management guide |

---

### IAM Service (`services/iam-service/`)

| File | Description |
|------|-------------|
| `main.go` | Server initialization, database connection with retry logic, migrations, router setup, health endpoint |
| `handlers.go` | HTTP handlers for Register, Login, Introspect, GetProfile, UpdateProfile; JWT middleware implementation |
| `models.go` | Data models: User, Role, RegisterRequest, LoginRequest, LoginResponse, UserDTO, IntrospectResponse, DTOs |
| `go.mod` | Go module dependencies |
| `go.sum` | Dependency checksums |
| `Dockerfile` | Docker image build configuration |

**Key Functions in `main.go`**:
- `connectDB()` - Database connection with retry logic (10 attempts, 3s interval)
- `runMigrations()` - Schema and table creation
- `createDefaultAdmin()` - Creates default admin user if none exists
- `getEnv()` - Environment variable helper

**Key Handlers in `handlers.go`**:
- `Register()` - Create new user account
- `Login()` - Authenticate and issue JWT
- `Introspect()` - Validate JWT token (used by other services)
- `GetProfile()` / `UpdateProfile()` - User profile management
- `JWTAuthMiddleware()` - JWT validation middleware
- `AdminOnly()` - Role-based authorization middleware

---

### Hardware Service (`services/hardware-service/`)

| File | Description |
|------|-------------|
| `main.go` | Server initialization, DB/MQTT connections, migrations, router setup |
| `handlers.go` | HTTP handlers for equipment, sensors, parameters, telemetry; MQTT callbacks |
| `models.go` | Data models including StringArray helper for PostgreSQL arrays, Equipment, Sensor, Parameter, TelemetryPayload |
| `go.mod` | Go module dependencies |
| `go.sum` | Dependency checksums |
| `Dockerfile` | Docker image build configuration |

**Key Functions in `main.go`**:
- `connectDB()` - Database connection with retry
- `connectMQTT()` - MQTT client with auto-reconnect
- `restoreSubscriptions()` - Re-subscribes to sensor topics on startup
- `runMigrations()` - Hardware schema creation
- `makeInternalRequest()` - Helper for inter-service REST calls

**Key Handlers in `handlers.go`**:
- `CreateEquipment()` / `ListEquipments()` - Equipment CRUD
- `DispatchControl()` - Send MQTT command to equipment
- `CreateSensor()` / `ListSensors()` - Sensor provisioning
- `CreateParameter()` / `ListParameters()` - Parameter type definitions
- `IngestTelemetry()` - REST telemetry ingestion
- `handleTelemetry()` - MQTT message callback for sensor data
- `handleEquipmentStatus()` - MQTT callback for equipment status updates
- `storeTelemetry()` - Persist telemetry and forward to analytics
- `forwardToAnalytics()` - Async telemetry forwarding

---

### Analytics Service (`services/analytics-service/`)

| File | Description |
|------|-------------|
| `main.go` | Server initialization, database connection, migrations, router setup |
| `handlers.go` | HTTP handlers for thresholds, rules, decisions, ingestion; automation logic |
| `models.go` | Data models: Threshold, AutomationRule, DailySummary, IngestPayload, DecisionTableEntry |
| `go.mod` | Go module dependencies |
| `go.sum` | Dependency checksums |
| `Dockerfile` | Docker image build configuration |

**Key Handlers in `handlers.go`**:
- `UpsertThreshold()` / `GetThreshold()` - Threshold management
- `CreateRule()` / `GetRulesForParameter()` - Automation rule management
- `GetDecisionSummary()` - Consolidated decision table with current status
- `Ingest()` - Process telemetry and trigger automation
- `GetDailySummaries()` - Daily aggregated statistics
- `updateDailySummary()` - Rolling daily aggregation
- `getWeatherScaleFactor()` - Fetch irrigation scale from Weather service
- `dispatchHardwareCommand()` - Trigger equipment control

---

### Weather Service (`services/weather-service/`)

| File | Description |
|------|-------------|
| `main.go` | Server initialization, configuration, router setup |
| `handlers.go` | HTTP handlers for weather data, forecasts, alerts, recommendations |
| `models.go` | Data models: WeatherCondition, Location, ForecastEntry, WeatherAlert, IrrigationRecommendation |
| `go.mod` | Go module dependencies |
| `go.sum` | Dependency checksums |
| `Dockerfile` | Docker image build configuration |

**Key Features**:
- Dual mode: Mock data (default) or live OpenWeatherMap API
- Configurable location (lat/lon)
- Irrigation recommendation algorithm

**Key Handlers in `handlers.go`**:
- `GetCurrentWeather()` - Current conditions
- `GetForecast()` - 24-hour forecast
- `GetAlerts()` - Weather warnings
- `GetRecommendations()` - Irrigation scale factor
- `fetchCurrentWeather()` - OpenWeatherMap API call
- `fetchForecast()` - OpenWeatherMap forecast API call
- `mockCurrentWeather()` - Mock data generator
- `mockForecast()` - Mock forecast generator
- `calculateRecommendation()` - Scale factor logic

---

### Notification Service (`services/notification-service/`)

| File | Description |
|------|-------------|
| `main.go` | Server initialization, DB, NATS consumer, SMTP setup |
| `handlers.go` | HTTP handlers for notifications and templates |
| `models.go` | Data models: NotificationRequest, Notification, Template |
| `store.go` | Database operations for notifications and templates |
| `dispatcher.go` | Notification routing and delivery orchestration |
| `channels.go` | Channel implementations (Email sender) |
| `templates.go` | Template rendering engine |
| `queue.go` | NATS consumer for async message processing |
| `go.mod` | Go module dependencies |
| `go.sum` | Dependency checksums |
| `Dockerfile` | Docker image build configuration |
| `docker-compose.yml` | Local NATS/Mailhog for development |
| `cmd/testpub/main.go` | Test publisher for NATS messages |

**Key Components**:
- `Store` - Database CRUD operations
- `Dispatcher` - Notification processing pipeline
- `TemplateEngine` - Go template rendering
- `EmailSender` - SMTP delivery
- `NATS Consumer` - Async message processing

---

### Gateway Configuration (`gateway/`)

| File | Description |
|------|-------------|
| `traefik.yml` | Traefik static configuration (entrypoints, API dashboard) |
| `routes.yml` | Dynamic route definitions (service backends) |

---

## API Endpoints Summary

### IAM Service
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/v1/iam/register` | No | Register new user |
| POST | `/api/v1/iam/login` | No | Login, get JWT |
| GET | `/api/v1/iam/introspect` | Bearer | Validate token |
| GET | `/api/v1/iam/profile` | Bearer | Get user profile |
| PUT | `/api/v1/iam/profile` | Bearer | Update profile |

### Hardware Service
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/v1/hardware/equipments` | Bearer | Register equipment |
| GET | `/api/v1/hardware/equipments` | Bearer | List equipment |
| POST | `/api/v1/hardware/control/{id}` | Bearer | Dispatch command |
| POST | `/api/v1/hardware/sensors` | Bearer | Provision sensor |
| GET | `/api/v1/hardware/sensors` | Bearer | List sensors |
| POST | `/api/v1/hardware/parameters` | Bearer | Define parameter |
| GET | `/api/v1/hardware/parameters` | Bearer | List parameters |
| POST | `/api/v1/hardware/telemetry` | Bearer | Ingest telemetry |

### Analytics Service
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/v1/analytics/thresholds` | Bearer | Create/update threshold |
| GET | `/api/v1/analytics/thresholds/{id}` | Bearer | Get threshold |
| POST | `/api/v1/analytics/rules` | Bearer | Create automation rule |
| GET | `/api/v1/analytics/rules/{id}` | Bearer | Get rules |
| GET | `/api/v1/analytics/decisions/summary` | Bearer | Decision table |
| POST | `/api/v1/analytics/ingest` | Bearer | Process telemetry |
| GET | `/api/v1/analytics/summaries` | Bearer | Daily summaries |

### Weather Service
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/v1/weather/current` | Bearer | Current weather |
| GET | `/api/v1/weather/forecast` | Bearer | 24h forecast |
| GET | `/api/v1/weather/alerts` | Bearer | Weather alerts |
| GET | `/api/v1/weather/recommendations` | Bearer | Irrigation scale |

### Notification Service
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/v1/notifications/send` | No | Send notification |
| GET | `/api/v1/notifications` | No | List notifications |
| GET | `/api/v1/notifications/{id}` | No | Get notification |
| POST | `/api/v1/templates` | No | Create template |
| GET | `/api/v1/templates` | No | List templates |
| GET | `/api/v1/templates/{id}` | No | Get template |
| PUT | `/api/v1/templates/{id}` | No | Update template |
| DELETE | `/api/v1/templates/{id}` | No | Delete template |

---

## Environment Variables

| Variable | Service | Default | Description |
|----------|---------|---------|-------------|
| `DB_HOST` | All | localhost | PostgreSQL host |
| `DB_PORT` | All | 5432 | PostgreSQL port |
| `DB_USER` | All | agriwizard | Database user |
| `DB_PASSWORD` | All | agriwizard_secret | Database password |
| `DB_NAME` | All | agriwizard | Database name |
| `JWT_SECRET` | All | (default) | JWT signing secret |
| `PORT` | All | (service default) | HTTP server port |
| `GIN_MODE` | All | debug | Gin mode (debug/release) |
| `MQTT_BROKER` | Hardware | tcp://localhost:1883 | MQTT broker URL |
| `MQTT_USERNAME` | Hardware | - | MQTT username |
| `MQTT_PASSWORD` | Hardware | - | MQTT password |
| `ANALYTICS_SERVICE_URL` | Hardware | http://analytics-service:8083 | Analytics service URL |
| `HARDWARE_SERVICE_URL` | Analytics | http://hardware-service:8082 | Hardware service URL |
| `WEATHER_SERVICE_URL` | Analytics | http://weather-service:8084 | Weather service URL |
| `USE_MOCK` | Weather | true | Use mock data |
| `OWM_API_KEY` | Weather | - | OpenWeatherMap API key |
| `OWM_BASE_URL` | Weather | https://api.openweathermap.org/data/2.5 | OWM API URL |
| `LOCATION_LAT` | Weather | 6.9271 | Location latitude |
| `LOCATION_LON` | Weather | 79.8612 | Location longitude |
| `LOCATION_CITY` | Weather | Colombo | Location name |
| `NATS_URL` | Notification | nats://localhost:4222 | NATS server URL |
| `SMTP_HOST` | Notification | localhost | SMTP server host |
| `SMTP_PORT` | Notification | 1025 | SMTP server port |
| `SMTP_FROM` | Notification | noreply@notification.local | SMTP from address |

---

## Common Patterns Across Services

### 1. Database Connection Pattern
All services implement a retry-based database connection:
```go
func connectDB(dsn string) (*sql.DB, error) {
    for i := 0; i < 10; i++ {
        db, err := sql.Open("postgres", dsn)
        if err == nil && db.Ping() == nil {
            // Configure connection pool
            db.SetMaxOpenConns(25)
            db.SetMaxIdleConns(5)
            db.SetConnMaxLifetime(5 * time.Minute)
            return db, nil
        }
        time.Sleep(3 * time.Second)
    }
    return nil, error
}
```

### 2. Health Check Pattern
Each service exposes a `/health` endpoint returning service status and dependency status:
```json
{
    "status": "ok",
    "service": "service-name",
    "db_ready": true,
    "migrated": true
}
```

### 3. JWT Middleware Pattern
All services implement JWT validation middleware:
```go
func (h *Handler) JWTAuthMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        // Check Authorization header
        // Parse and validate JWT
        // Set user claims in context
        c.Next()
    }
}
```

### 4. Error Response Pattern
Standardized error response format:
```json
{
    "error": "error_code",
    "message": "human readable message"
}
```

### 5. Success Response Pattern
Standardized success response format:
```json
{
    "message": "success message",
    "data": { ... }
}
```

---

## Data Flow Examples

### Sensor Data Flow
```
Sensor Device → MQTT Topic → Hardware Service → Store in DB → Forward to Analytics Service → Evaluate Thresholds → Trigger Equipment Control
```

### Automation Flow
```
Telemetry Received → Check Thresholds → If Breach → Get Linked Rules → Get Weather Scale Factor → Dispatch Command to Hardware → MQTT → Equipment
```

### Notification Flow
```
Trigger (API/NATS) → Resolve Template → Persist Record → Route to Channel → Send via SMTP → Update Status
```

---

## Testing

### Bruno API Tests (`bruno/`)

The project includes Bruno API collection for testing:
- `00-IAM/` - Authentication tests
- `01-Hardware/` - Device management tests
- `02-Analytics/` - Threshold and automation tests
- `03-Weather/` - Weather service tests
- `04-Notifications/` - Notification service tests

### Example End-to-End Flow

1. Register user: `POST /api/v1/iam/register`
2. Login: `POST /api/v1/iam/login` → Get JWT token
3. Create parameter: `POST /api/v1/hardware/parameters`
4. Register equipment: `POST /api/v1/hardware/equipments`
5. Provision sensor: `POST /api/v1/hardware/sensors`
6. Set threshold: `POST /api/v1/analytics/thresholds`
7. Create rule: `POST /api/v1/analytics/rules`
8. Send telemetry: `POST /api/v1/hardware/telemetry`
9. Check decisions: `GET /api/v1/analytics/decisions/summary`
10. Get recommendations: `GET /api/v1/weather/recommendations`

---

## Security Features

1. **JWT Authentication** - All protected endpoints use Bearer token authentication
2. **Role-Based Access Control (RBAC)** - Admin and Agromist roles
3. **Service-to-Service Authentication** - Internal calls use `X-Internal-Service` header
4. **Password Hashing** - bcrypt for password storage
5. **Principle of Least Privilege** - Each service uses separate database schema

---

## CI/CD Pipeline

The project uses GitHub Actions with the following stages:
1. **SAST** - SonarCloud static analysis
2. **Dependency Scan** - Snyk vulnerability scanning
3. **Build** - Docker image builds
4. **Push** - Push to Azure Container Registry
5. **Deploy** - Deploy to Azure Container Apps

---

*Document generated for AgriWizard Smart Greenhouse Management System*
