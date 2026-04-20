# AgriWizard API Gateway Integration (ACA + Kong)

This document captures the current architecture analysis and the production-ready target design using **Kong Gateway on Azure Container Apps (ACA)**.

## Step 1: Existing Architecture Summary (As-Is)

### Microservices discovered

| Service | Language/Framework | Port | Health endpoint | Dockerfile | Notes |
|---|---|---:|---|---|---|
| `iam-service` | Go + Gin | `8081` | `/health` | `services/iam-service/Dockerfile` | Issues JWT tokens and handles auth/profile |
| `hardware-service` | Go + Gin + MQTT client | `8082` | `/health` | `services/hardware-service/Dockerfile` | Sensor/equipment APIs, telemetry ingest, forwards to analytics |
| `analytics-service` | Go + Gin | `8083` | `/health` | `services/analytics-service/Dockerfile` | Threshold/rules engine, calls hardware + weather |
| `weather-service` | Go + Gin | `8084` | `/health` | `services/weather-service/Dockerfile` | Weather + irrigation recommendations |
| `notification-service` | Go (`net/http`) | `8085` | `/health` | `services/notification-service/Dockerfile` | Notifications/templates, NATS + Service Bus consumers |

### Communication model

- **Protocol**: REST/HTTP between services.
- **Service discovery**: Static DNS/service URLs (`http://<service-name>:<port>` style in Docker network).
- **No Eureka/gRPC/service mesh** detected.

### Inter-service dependencies (runtime)

- `hardware-service -> analytics-service` (`/api/v1/analytics/ingest`)
- `analytics-service -> hardware-service` (`/api/v1/hardware/control/:id`)
- `analytics-service -> weather-service` (`/api/v1/weather/recommendations`)

### Existing gateway/routing state

- Gateway assets already existed under `infrastructure/kong/` but mixed modes were present:
  - DB-backed Kong variants.
  - VM-based Kong Terraform (`terraform/kong-vm.tf`).
  - Static endpoint mapping to public ACA FQDNs.
- Root `docker-compose.yml` also had DB-backed Kong.

### Env/config pattern

- Services read from env vars with sensible defaults.
- `PORT`, `DB_*`, `JWT_SECRET`, service URLs (`*_SERVICE_URL`) are already externalized.
- Most services are container-ready and independent when env vars are supplied.

## Step 2: Target Architecture (To-Be)

### Design goals

- One public edge: **Kong**.
- All backend services: **internal ingress only**.
- ACA-native service discovery (`http://<app-name>:<port>`).
- DB-less Kong with declarative config.
- Keep solution simple and cost-aware.

### Diagram (Mermaid)

```mermaid
flowchart LR
  U[Client / Frontend] --> K[Kong Gateway<br/>ACA External Ingress]

  subgraph ACA Environment (Private Service Mesh-like network)
    I[IAM Service<br/>internal:8081]
    H[Hardware Service<br/>internal:8082]
    A[Analytics Service<br/>internal:8083]
    W[Weather Service<br/>internal:8084]
    N[Notification Service<br/>internal:8085]
  end

  K --> I
  K --> H
  K --> A
  K --> W
  K --> N

  H --> A
  A --> H
  A --> W

  subgraph Shared Platform
    PG[(PostgreSQL)]
    SB[(Azure Service Bus)]
    MQ[(HiveMQ / MQTT)]
    AI[(Application Insights)]
    LA[(Log Analytics)]
  end

  I --> PG
  H --> PG
  A --> PG
  N --> PG

  H --> SB
  A --> SB
  N --> SB

  H --> MQ

  K --> AI
  I --> AI
  H --> AI
  A --> AI
  W --> AI
  N --> AI

  AI --> LA
```

### Public vs private ingress

- **Public (`external`)**: `kong-gateway` only.
- **Private (`internal`)**: `iam-service`, `hardware-service`, `analytics-service`, `weather-service`, `notification-service`.

## Step 3: Service Prep Changes Implemented

### Containerization

- All services already had valid Dockerfiles.
- Added Kong runtime image: `infrastructure/kong/Dockerfile`.

### Internal communication fixes

- Added internal-call bypass for hardware auth middleware (`X-Internal-Service`) so analytics automation calls work.
- Updated analytics weather call to send `X-Internal-Service` and handle non-200 responses safely.

### JWT compatibility for Kong JWT plugin

- IAM tokens now include issuer claim `iss`.
- Added configurable issuer env var:
  - `JWT_ISSUER` (default: `agriwizard-iam`).

### Local stack alignment

- Root `docker-compose.yml` migrated to **DB-less Kong**.
- Removed local Kong Postgres dependency.

## Step 4: Azure Infrastructure Setup (Scripts)

Scripts added under `infrastructure/aca/`:

- `01-bootstrap.sh`
  - Resource Group
  - Log Analytics
  - Application Insights
  - ACR
  - ACA Environment
- `02-build-push.sh`
  - Builds and pushes all service images + Kong image to ACR
- `aca.env.example`
  - Template for deployment variables

## Step 5: Deploy Microservices to ACA

Script:

- `03-deploy-services.sh`

Behavior:

- Deploys each backend app with **internal ingress**.
- Sets `PORT`, DB/JWT/service URLs, telemetry vars, and App Insights connection string.
- Scaling:
  - `weather-service`: `min=0` (scale-to-zero).
  - `iam/hardware/analytics/notification`: `min=1` (kept warm due auth/background processing).

Internal reachability target:

- `http://iam-service:8081`
- `http://hardware-service:8082`
- `http://analytics-service:8083`
- `http://weather-service:8084`
- `http://notification-service:8085`

## Step 6: Kong Implementation (DB-less)

### Files

- `infrastructure/kong/kong.yml` (declarative config template)
- `infrastructure/kong/entrypoint.sh` (env render + startup)
- `infrastructure/kong/Dockerfile`

### Route mappings

Clean aliases and backward-compatible paths:

- `/auth` and `/api/v1/iam` -> IAM
- `/hardware` and `/api/v1/hardware` -> Hardware
- `/analytics` and `/api/v1/analytics` -> Analytics
- `/weather` and `/api/v1/weather` -> Weather
- `/notifications` and `/api/v1/notifications` -> Notification
- `/templates` and `/api/v1/templates` -> Notification templates

## Step 7: Deploy Kong to ACA

Script:

- `04-deploy-kong.sh`

Behavior:

- Deploys `kong-gateway` with **external ingress**.
- Target port `8000`.
- Uses internal ACA DNS hosts for upstreams.
- Keeps Kong admin listener internal to the container (`127.0.0.1:8001`).

## Step 8: Gateway Features Enabled

Configured in `infrastructure/kong/kong.yml`:

- **JWT auth** on protected routes using Kong JWT plugin.
- **Rate limiting** (global).
- **CORS** (global, env-controlled origin).

## Step 9: Observability & Debugging

Implemented via ACA + scripts:

- Container Apps Environment bound to **Log Analytics**.
- **Application Insights** created and connection string injected as env var into:
  - Kong
  - IAM
  - Hardware
  - Analytics
  - Weather
  - Notification

Operational commands:

```bash
az containerapp logs show --name kong-gateway --resource-group <rg> --follow
az monitor app-insights query --app <app-insights-name> --analytics-query "traces | take 50"
```

## Step 10: Testing

Script:

- `05-test-gateway.sh`

What it validates:

1. Login through Kong (`/auth/login`) and token acquisition.
2. Protected route access through Kong (`/weather/...`, `/analytics/...`).
3. Backend exposure flags (`external=false` expected for internal services).

Sample manual requests:

```bash
# login
curl -X POST "https://<kong-fqdn>/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@agriwizard.local","password":"admin123"}'

# call protected route
curl "https://<kong-fqdn>/analytics/decisions/summary" \
  -H "Authorization: Bearer <jwt>"
```

## Step 11: Optimization Decisions

- Switched Kong to **DB-less** mode:
  - removes extra Kong database cost/ops burden.
- Single public ingress (Kong only):
  - better security boundary.
- Kept stateful/event-driven apps warm (`min=1`) to avoid missed background processing.
- Used `min=0` on weather service where scale-to-zero is safe.
- Existing VM-based Kong deployment path (`terraform/kong-vm.tf`) is now functionally redundant for ACA-first deployments.

## Deployment Runbook

```bash
cp infrastructure/aca/aca.env.example infrastructure/aca/aca.env
# edit infrastructure/aca/aca.env

bash infrastructure/aca/deploy-all.sh infrastructure/aca/aca.env
bash infrastructure/aca/05-test-gateway.sh infrastructure/aca/aca.env
```

## Changed File Summary

- Gateway:
  - `infrastructure/kong/kong.yml`
  - `infrastructure/kong/Dockerfile`
  - `infrastructure/kong/entrypoint.sh`
  - `infrastructure/kong/kong.conf`
  - `infrastructure/kong/docker-compose.kong.yml`
  - `infrastructure/kong/docker-compose.kong.standalone.yml`
  - `infrastructure/kong/startup.sh`
- Services:
  - `services/iam-service/main.go`
  - `services/iam-service/handlers.go`
  - `services/hardware-service/handlers.go`
  - `services/analytics-service/handlers.go`
- Local env/runtime:
  - `.env.example`
  - `docker-compose.yml`
- ACA automation:
  - `infrastructure/aca/aca.env.example`
  - `infrastructure/aca/common.sh`
  - `infrastructure/aca/01-bootstrap.sh`
  - `infrastructure/aca/02-build-push.sh`
  - `infrastructure/aca/03-deploy-services.sh`
  - `infrastructure/aca/04-deploy-kong.sh`
  - `infrastructure/aca/05-test-gateway.sh`
  - `infrastructure/aca/deploy-all.sh`
  - `infrastructure/aca/README.md`
