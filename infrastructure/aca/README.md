# ACA + Kong Deployment Scripts

This folder contains Azure CLI scripts to deploy AgriWizard to **Azure Container Apps (ACA)** with:

- one **public Kong Gateway** (`kong-gateway`)
- all backend services as **internal-only ACA apps**
- DB-less Kong declarative config (`infrastructure/kong/kong.yml`)

## Prerequisites

- Azure CLI logged in (`az login`)
- `containerapp` extension installed (CLI will prompt if missing)
- Dockerfiles already available in `services/*/Dockerfile` and `infrastructure/kong/Dockerfile`

## Quick Start

1. Copy env template:
   - `cp infrastructure/aca/aca.env.example infrastructure/aca/aca.env`
2. Fill required values in `infrastructure/aca/aca.env`.
3. Run full deployment:
   - `bash infrastructure/aca/deploy-all.sh infrastructure/aca/aca.env`

## Script Order

1. `01-bootstrap.sh`
   - Creates Resource Group, Log Analytics, Application Insights, ACR, ACA Environment.
2. `02-build-push.sh`
   - Builds and pushes all service images + Kong image to ACR.
3. `03-deploy-services.sh`
   - Deploys internal service apps (`iam-service`, `hardware-service`, `analytics-service`, `weather-service`, `notification-service`).
4. `04-deploy-kong.sh`
   - Deploys `kong-gateway` with **external ingress** on port 8000.
5. `05-test-gateway.sh`
   - Runs smoke tests via Kong and checks service exposure flags.

## Internal DNS Convention

Services are reachable inside the ACA environment via:

- `http://iam-service:8081`
- `http://hardware-service:8082`
- `http://analytics-service:8083`
- `http://weather-service:8084`
- `http://notification-service:8085`

## Notes

- `weather-service` is configured with `min-replicas=0` (scale-to-zero friendly).
- Stateful/event-driven services (`iam`, `hardware`, `analytics`, `notification`) are kept warm (`min-replicas=1`) to avoid cold-start gaps in auth and background consumers.
- Kong route aliases are provided for clean public paths:
  - `/auth`, `/hardware`, `/analytics`, `/weather`, `/notifications`, `/templates`
  - Legacy compatibility retained for `/api/v1/*` paths.
