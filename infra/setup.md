# AgriWizard Azure + GitHub OIDC Setup

This document provisions Azure resources for CI/CD and configures GitHub Actions to deploy to Azure Container Apps (ACA) using Workload Identity Federation (OIDC), without long-lived Azure credentials.

## 1) Prerequisites

- Azure CLI `2.59+`
- Logged in: `az login`
- Subscription selected: `az account set --subscription "<SUBSCRIPTION_ID_OR_NAME>"`
- GitHub repository admin access (to set secrets/variables and environment protection rules)

## 2) Set reusable shell variables

```bash
export LOCATION="southeastasia"
export RG="rg-agriwizard-prod"
export ACR_NAME="agriwizardacr$RANDOM"
export ACA_ENV_NAME="agriwizard-aca-env"
export LOG_ANALYTICS_NAME="agriwizard-law"
export GITHUB_ORG="<github-org-or-user>"
export GITHUB_REPO="<repo-name>"
export GH_BRANCH="main"
```

## 3) Create Azure resource group

```bash
az group create \
  --name "$RG" \
  --location "$LOCATION"
```

## 4) Create ACR

```bash
az acr create \
  --name "$ACR_NAME" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --sku Standard \
  --admin-enabled false
```

## 5) Create Log Analytics workspace (required by ACA environment)

```bash
az monitor log-analytics workspace create \
  --resource-group "$RG" \
  --workspace-name "$LOG_ANALYTICS_NAME" \
  --location "$LOCATION"

LA_CUSTOMER_ID="$(az monitor log-analytics workspace show \
  --resource-group "$RG" \
  --workspace-name "$LOG_ANALYTICS_NAME" \
  --query customerId -o tsv)"

LA_SHARED_KEY="$(az monitor log-analytics workspace get-shared-keys \
  --resource-group "$RG" \
  --workspace-name "$LOG_ANALYTICS_NAME" \
  --query primarySharedKey -o tsv)"
```

## 6) Create ACA managed environment

```bash
az containerapp env create \
  --name "$ACA_ENV_NAME" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --logs-workspace-id "$LA_CUSTOMER_ID" \
  --logs-workspace-key "$LA_SHARED_KEY"
```

## 7) Create staging + production Container Apps (one per service)

Run once for each app listed below. Update the image name if needed.

```bash
# Example for IAM staging
az containerapp create \
  --name agriwizard-iam-stg \
  --resource-group "$RG" \
  --environment "$ACA_ENV_NAME" \
  --image "$ACR_NAME.azurecr.io/agriwizard-iam:latest" \
  --ingress external \
  --target-port 8086 \
  --cpu 0.5 \
  --memory 1.0Gi \
  --min-replicas 1 \
  --max-replicas 3 \
  --registry-server "$ACR_NAME.azurecr.io"
```

Create these apps (staging and production):
- `agriwizard-iam-stg`, `agriwizard-iam-prod`
- `agriwizard-hardware-stg`, `agriwizard-hardware-prod`
- `agriwizard-analytics-stg`, `agriwizard-analytics-prod`
- `agriwizard-weather-stg`, `agriwizard-weather-prod`
- `agriwizard-notification-stg`, `agriwizard-notification-prod`
- `agriwizard-web-stg`, `agriwizard-web-prod`

## 8) Create Microsoft Entra app + service principal for GitHub OIDC

```bash
APP_NAME="agriwizard-github-oidc"

APP_ID="$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)"
az ad sp create --id "$APP_ID"

SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"
SP_OBJECT_ID="$(az ad sp show --id "$APP_ID" --query id -o tsv)"
```

Grant least-privilege roles on the resource group:

```bash
az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role AcrPush \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG"

az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG"
```

Create federated credential for the GitHub Actions branch:

```bash
cat > /tmp/gh-main-credential.json <<EOF
{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/${GH_BRANCH}",
  "audiences": [
    "api://AzureADTokenExchange"
  ]
}
EOF

az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters /tmp/gh-main-credential.json
```

Optional: add PR credential if you later want OIDC login from PR events.

## 9) Configure GitHub environments and approval gates

In GitHub repo settings:
- Create environment `staging` (optional reviewers)
- Create environment `production` and add **required reviewers** for manual approval

The workflow already targets these environment names.

## 10) Configure required GitHub Secrets

Add these in **Settings -> Secrets and variables -> Actions -> Secrets**:

- `AZURE_CLIENT_ID` - App (client) ID from the Entra application used for OIDC
- `AZURE_TENANT_ID` - Tenant ID that owns the Entra app
- `AZURE_SUBSCRIPTION_ID` - Azure subscription containing ACR/ACA
- `DB_PASSWORD` - Database password injected into container apps
- `JWT_SECRET` - JWT signing secret for services
- `MQTT_PASSWORD` - MQTT password (leave empty only if not used)
- `OWM_API_KEY` - OpenWeather API key
- `SMTP_PASSWORD` - SMTP password/API key
- `SERVICE_BUS_CONNECTION` - Azure Service Bus connection string

## 11) Configure required GitHub Variables

Add these in **Settings -> Secrets and variables -> Actions -> Variables**:

Core Azure:
- `ACR_LOGIN_SERVER` - e.g., `myregistry.azurecr.io`
- `ACA_RESOURCE_GROUP_STAGING` - resource group for staging apps
- `ACA_ENVIRONMENT_STAGING` - ACA environment name for staging
- `ACA_RESOURCE_GROUP_PRODUCTION` - resource group for production apps
- `ACA_ENVIRONMENT_PRODUCTION` - ACA environment name for production

Container App names (staging):
- `ACA_APP_IAM_STAGING`
- `ACA_APP_HARDWARE_STAGING`
- `ACA_APP_ANALYTICS_STAGING`
- `ACA_APP_WEATHER_STAGING`
- `ACA_APP_NOTIFICATION_STAGING`
- `ACA_APP_WEB_STAGING`

Container App names (production):
- `ACA_APP_IAM_PRODUCTION`
- `ACA_APP_HARDWARE_PRODUCTION`
- `ACA_APP_ANALYTICS_PRODUCTION`
- `ACA_APP_WEATHER_PRODUCTION`
- `ACA_APP_NOTIFICATION_PRODUCTION`
- `ACA_APP_WEB_PRODUCTION`

Runtime tuning:
- `ACA_CPU` (default in workflow: `0.5`)
- `ACA_MEMORY` (default in workflow: `1Gi`)
- `ACA_MIN_REPLICAS` (default staging: `1`, production: `2`)
- `ACA_MAX_REPLICAS` (default staging: `3`, production: `5`)

Non-secret app config:
- `DB_HOST`
- `DB_PORT`
- `DB_USER`
- `DB_NAME`
- `DB_SSLMODE`
- `JWT_ISSUER`
- `OWM_BASE_URL`
- `LOCATION_LAT`
- `LOCATION_LON`
- `LOCATION_CITY`
- `USE_MOCK`
- `NEXT_PUBLIC_API_URL`
- `NEXT_PUBLIC_BASE_PATH`

## 12) Validation checklist

- Push a commit to a feature branch -> `lint`, `test`, `build` should run
- Open PR to `main` -> `lint`, `test`, `build` should run, no push/deploy
- Merge to `main` -> push to ACR + deploy staging should run
- Approve production environment -> production deployment proceeds
- Verify each app revision in ACA:

```bash
az containerapp revision list \
  --name agriwizard-iam-stg \
  --resource-group "$RG" \
  -o table
```
