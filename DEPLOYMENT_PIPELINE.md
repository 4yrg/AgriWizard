# AgriWizard Deployment Pipeline

This document outlines the production CI/CD pipeline for the AgriWizard Smart Greenhouse Management System.

## Architecture

- **Infrastructure**: Azure Bicep (IaC) — modular templates under `infra/`
- **Hosting**: Azure Container Apps (ACA) — consumption plan
- **Database**: Azure Database for PostgreSQL Flexible Server
- **Messaging**: Azure Service Bus (replaces RabbitMQ/NATS in production)
- **MQTT**: HiveMQ Cloud (managed, retained as-is)
- **Registry**: Azure Container Registry (ACR)
- **Gateway**: Kong API Gateway (running as a Container App)
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
| API Gateway | Kong container | Kong (Container App) |
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

### 3. Initial Deployment
**Important:** You must deploy infrastructure BEFORE building app images. The deploy workflow will fail if no ACR exists.

| Step | Workflow | Description |
|------|----------|-------------|
| 1 | `infra.yml` | Run manually with `confirm_deploy=DEPLOY` to create ACR, PostgreSQL, Service Bus, Key Vault, Container Apps Environment, and all container apps |
| 2 | `deploy.yml` | Run manually with `deploy_all=true` to build and push images, then deploy to container apps |

```bash
# 1. Trigger infra.yml workflow manually with confirm_deploy=DEPLOY
#    (Creates: ACR, DB, Service Bus, Key Vault, Container Apps)

# 2. Trigger deploy.yml workflow manually with deploy_all=true
#    (Builds images and deploys to container apps)
```

### 4. Managed MQTT Configuration
Managed MQTT credentials are stored in **Azure Key Vault** and injected into Container Apps via environment variables.

Key Vault Secret Names:
- `mqtt-broker`
- `mqtt-username`
- `mqtt-password`

## Troubleshooting

### No ACR Found Error
If you see `Could not connect to the registry login server` or `The resource with name '...' could not be found`:
1. **Run the `infra` workflow first** - This creates the Azure Container Registry
2. Trigger it manually with `confirm_deploy=DEPLOY`

### Connectivity Issues
If you see `ERR_CONNECTION_REFUSED`, verify:
1. **Local**: Kong is running on port `8000` (check `KONG_PROXY_PORT` in `.env`).
2. **Production**: Check the Kong FQDN in the Azure Portal or via `make health`.

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
