# AgriWizard — Deployment Guide

This guide covers both **local development** and **production deployment** to Azure.

---

## 1. Local Development

### Prerequisites

| Tool | Version |
|------|---------|
| Docker & Docker Compose | v2.20+ |
| Go | 1.22+ |
| Node.js | 20+ |
| make | any |

### Quick Start

```bash
# Clone the repository
git clone https://github.com/<org>/agriwizard.git
cd agriwizard

# Copy environment file
cp .env.example .env

# Start all services (detached)
make up
```

### Service Endpoints (Local)

| Service | URL |
|---|---|
| Web Dashboard (Next.js) | http://localhost:3000 |
| Kong API Gateway | http://localhost:8000 |
| Swagger UI | http://localhost:8090 |
| Mailhog (Email UI) | http://localhost:8098 |
| RabbitMQ Management | http://localhost:8093 |
| IAM Service (direct) | http://localhost:8081 |
| Hardware Service (direct) | http://localhost:8082 |
| Analytics Service (direct) | http://localhost:8083 |
| Weather Service (direct) | http://localhost:8085 |
| Notification Service (direct) | http://localhost:8096 |

### Default Credentials

```
Admin: admin@agriwizard.local / admin123
```

### Common Commands

```bash
make up          # Start all services
make down        # Stop all services
make rebuild     # Rebuild images and restart
make logs        # Tail logs (all services)
make logs-iam    # Tail IAM service logs
make test        # Run Go unit tests
make lint        # Run golangci-lint + Next.js lint
make ping        # Check health of all services
```

---

## 2. Production Deployment (Azure)

### Architecture

Production runs on **Microsoft Azure** using:

- **Azure Container Apps** – serverless container hosting for all microservices
- **Azure Container Registry (ACR)** – private image registry (`agriwizardacr.azurecr.io`)
- **Azure Database for PostgreSQL** – managed, HA-enabled PostgreSQL 16
- **Azure Service Bus** – managed message queue for Hardware → Analytics events

### CI/CD Pipeline

The pipeline is defined in `.github/workflows/ci-cd.yml` and consists of 3 jobs:

#### Job 1: `test` (runs on every PR + push)
1. Runs `golangci-lint` across the monorepo
2. Runs `go test -v -race ./...` for each service

#### Job 2: `build-and-push` (runs on push to `main` only)
1. Authenticates to Azure via `AZURE_CREDENTIALS` secret
2. Uses `az acr build` to build and push images for all 6 containers:
   - `agriwizard-iam-service:latest`
   - `agriwizard-hardware-service:latest`
   - `agriwizard-analytics-service:latest`
   - `agriwizard-weather-service:latest`
   - `agriwizard-notification-service:latest`
   - `agriwizard-frontend:latest`

#### Job 3: `deploy` (runs on push to `main` only)
1. Authenticates to Azure
2. Updates each Container App to the new image revision:
   - `agriwizard-dev-iam`
   - `agriwizard-dev-hardware`
   - `agriwizard-dev-analytics`
   - `agriwizard-dev-weather`
   - `agriwizard-dev-notification`
   - `agriwizard-dev-frontend`
3. Runs a health check against Kong Gateway
4. On failure: **automatic rollback** to the previous active revision

### Required GitHub Secrets

| Secret | Description |
|---|---|
| `AZURE_CREDENTIALS` | JSON service principal with AcrPush + ContainerApp Contributor roles |

Generate credentials:
```bash
az ad sp create-for-rbac \
  --name "agriwizard-github-actions" \
  --role contributor \
  --scopes /subscriptions/<SUB_ID>/resourceGroups/agriwizard-dev-rg \
  --sdk-auth
```

Paste the JSON output as the `AZURE_CREDENTIALS` secret in GitHub.

### Environment Variables (Production)

Set these as Container App secrets / environment variables via the Azure portal or CLI:

| Variable | Example |
|---|---|
| `DB_HOST` | `agriwizard-db.postgres.database.azure.com` |
| `DB_USER` | `agriwizard` |
| `DB_PASSWORD` | `<secret>` |
| `DB_NAME` | `agriwizard` |
| `DB_SSLMODE` | `require` |
| `JWT_SECRET` | `<strong-random-secret>` |
| `MQTT_BROKER` | `ssl://<hivemq-host>:8883` |
| `OWM_API_KEY` | `<openweathermap-key>` |
| `USE_MOCK` | `false` |

---

## 3. Manual Rollback

If automatic rollback doesn't trigger, you can manually roll back any Container App:

```bash
# List revisions
az containerapp revision list \
  --name agriwizard-dev-iam \
  --resource-group agriwizard-dev-rg \
  --query '[].{name:name,active:properties.active,created:properties.createdTime}' \
  -o table

# Activate a previous revision
az containerapp ingress traffic set \
  --name agriwizard-dev-iam \
  --resource-group agriwizard-dev-rg \
  --revision-weight <PREV_REVISION_NAME>=100
```

---

## 4. Monitoring

```bash
# Stream logs for a Container App
az containerapp logs show \
  --name agriwizard-dev-iam \
  --resource-group agriwizard-dev-rg \
  --follow

# Check health
curl https://<kong-fqdn>/health
```
