# AgriWizard Deployment Pipeline

This document outlines the production CI/CD pipeline for the AgriWizard Smart Greenhouse Management System.

## Architecture

- **Infrastructure**: Azure Bicep (IaC) — modular templates under `infra/`
- **Hosting**: Azure Container Apps (ACA) — consumption plan
- **Database**: Azure Database for PostgreSQL Flexible Server
- **Messaging**: Azure Service Bus (replaces RabbitMQ/NATS in production)
- **MQTT**: HiveMQ Cloud (managed, retained as-is)
- **Registry**: Azure Container Registry (ACR)
- **Gateway**: Azure API Management (APIM) — managed gateway
- **Secrets**: Azure Key Vault
- **Logging**: Azure Log Analytics Workspace
- **CI/CD**: GitHub Actions
- **Auth**: OIDC Federated Identity (Secretless)

## Local Dev vs Production

| Component | Local Development | Production (Azure) |
|---|---|---|
| Database | PostgreSQL container (docker-compose) | Azure PostgreSQL Flexible Server |
| Messaging | RabbitMQ + NATS containers | Azure Service Bus |
| Email | Mailhog container | SMTP provider (configurable) |
| MQTT | HiveMQ Cloud | HiveMQ Cloud (same) |
| API Gateway | Kong container | Azure API Management (APIM) |
| Secrets | `.env` file | Azure Key Vault |
| Logging | Docker logs | Azure Log Analytics |

> **Note:** The Go services have dual-path code — they initialize both RabbitMQ and Service Bus clients, and gracefully degrade when a connection string is empty. The environment variables control which messaging path is active.

## Bicep Module Structure

```
infra/
├── main.bicep                          # Root orchestrator
├── parameters/
│   └── production.bicepparam           # Production parameter values
└── modules/
    ├── container-registry.bicep        # Azure Container Registry (Basic)
    ├── log-analytics.bicep             # Log Analytics Workspace
    ├── keyvault.bicep                  # Key Vault + all secrets
    ├── postgresql.bicep                # PostgreSQL Flexible Server
    ├── servicebus.bicep                # Service Bus + topics + subscriptions
    ├── container-apps-env.bicep        # Container Apps Environment
    └── container-app.bicep             # Reusable per-app module (×7)
```

## Workflows

### 1. Infrastructure (`infra.yml`)
- Triggered manually or on changes to `infra/**`.
- Validates Bicep templates.
- Runs `what-if` preview.
- Deploys/updates Azure resources.
- Secrets are injected as `--parameters` overrides from GitHub Secrets.

### 2. Build & Deploy (`deploy.yml`)
- Triggered on push to `main`.
- **Change Detection**: Only builds and deploys services that have changed.
- **Testing**: Runs Go tests and Next.js lint/build.
- **Versioning**: Tags images with `latest`, `sha-<commit>`, and `YYYYMMDD-HHMM`.
- **Zero-Downtime**: ACA handles rolling updates with new revisions.
- **Rollback**: Automatically reverts to the previous stable revision if smoke tests fail.

### 3. Release (`release.yml`)
- Triggered on Git tags (e.g., `v1.0.0`).
- Creates immutable release images.
- Generates a release summary.

### 4. Maintenance (`cleanup.yml`)
- Runs nightly.
- Prunes untagged images from ACR.
- Cleans up old inactive ACA revisions.

## Setup Instructions

### 1. Azure OIDC Setup
Run the bootstrap script to create the identity and federated credentials:
```bash
chmod +x scripts/bootstrap.sh
./scripts/bootstrap.sh rg-agriwizard centralindia your-org/AgriWizard
```
This creates the resource group and OIDC identity. After bootstrapping, add the GitHub secrets.

### 2. GitHub Secrets
Add the following secrets to your GitHub repository:

| Secret | Description |
|---|---|
| `AZURE_CLIENT_ID` | OIDC federated identity client ID |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `POSTGRES_ADMIN_PASSWORD` | PostgreSQL admin password |
| `JWT_SECRET` | JWT signing key |
| `MQTT_BROKER` | HiveMQ broker URL (e.g., `ssl://cluster.hivemq.cloud:8883`) |
| `MQTT_USERNAME` | HiveMQ username |
| `MQTT_PASSWORD` | HiveMQ password |
| `OWM_API_KEY` | OpenWeatherMap API key |

### 3. Automated Deployment
AgriWizard uses a self-bootstrapping pipeline. You do **not** need to manually create resources.

**Deployment Steps:**
1. **Bootstrap Identity**: Run `./scripts/bootstrap.sh` once to set up the Azure OIDC identity and GitHub secrets.
2. **Push to Main**: Simply push your code. The `deploy` workflow will:
   - Create the Resource Group and ACR if missing.
   - Provision all Azure services (PostgreSQL, Service Bus, APIM, etc.).
   - Build and push container images.
   - Deploy the application to Container Apps.

> **Note:** The first deployment will use "placeholder" images to establish the infrastructure. The pipeline will automatically replace them with your real code in the subsequent build/deploy steps.

### 4. Managed MQTT Configuration
Managed MQTT credentials are stored in **Azure Key Vault** and injected into Container Apps via environment variables.

Key Vault Secret Names:
- `mqtt-broker`
- `mqtt-username`
- `mqtt-password`

## Troubleshooting

### Environment Not Found
If the infrastructure hasn't been created yet, ensure your GitHub Secrets are set correctly and trigger the `deploy` workflow. It will automatically create the ACR and other resources.

### Missing GitHub Secrets
Add the required secrets (see bootstrap output):
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `POSTGRES_ADMIN_PASSWORD`
- `JWT_SECRET`
- `MQTT_BROKER`, `MQTT_USERNAME`, `MQTT_PASSWORD`
- `OWM_API_KEY`

### Connectivity Issues
If you see connection errors, verify:
1. **Local**: Kong is running on port `8000` (check `KONG_PROXY_PORT` in `.env`).
2. **Production**: Check the APIM Gateway URL in the Azure Portal or the workflow outputs.

### Deployment Failures
Check the GitHub Actions logs. If a deployment fails during smoke tests, the `rollback-on-failure` job will trigger automatically.

To manually rollback:
```bash
make rollback
```

### MQTT Connectivity
Test the managed MQTT broker connectivity:
```bash
export MQTT_HOST=...
export MQTT_USERNAME=...
export MQTT_PASSWORD=...
make mqtt-check
```

### Bicep Validation
To validate templates locally without deploying:
```bash
az bicep build --file infra/main.bicep
```
