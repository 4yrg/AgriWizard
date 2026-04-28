# AgriWizard Deployment Pipeline

This document outlines the production CI/CD pipeline for the AgriWizard Smart Greenhouse Management System.

## Architecture
- **Infrastructure**: Azure Bicep (IaC)
- **Hosting**: Azure Container Apps (ACA)
- **Registry**: Azure Container Registry (ACR)
- **Gateway**: Kong API Gateway
- **CI/CD**: GitHub Actions
- **Auth**: OIDC Federated Identity (Secretless)

## Workflows

### 1. Infrastructure (`infra.yml`)
- Triggered manually or on changes to `infra/**`.
- Validates Bicep templates.
- Runs `what-if` preview.
- Deploys/updates Azure resources.

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
./scripts/bootstrap.sh <resource-group> <location> <github-org/repo>
```

### 2. GitHub Secrets
Add the following secrets to your GitHub repository:
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

### 3. Managed MQTT Configuration
Managed MQTT credentials should be stored in **Azure Key Vault**. The Container Apps are configured to reference these secrets.
Key Vault Secret Names:
- `mqtt-host`
- `mqtt-port`
- `mqtt-username`
- `mqtt-password`

## Troubleshooting

### Connectivity Issues
If you see `ERR_CONNECTION_REFUSED`, verify:
1. **Local**: Kong is running on port `8080` (check `KONG_PROXY_PORT` in `.env`).
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
