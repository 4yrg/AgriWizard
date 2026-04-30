# Required GitHub Secrets and Variables

| Name | Type | Description | How to obtain | Used in |
| --- | --- | --- | --- | --- |
| `AZURE_CLIENT_ID` | Secret | OIDC app registration (service principal) client ID | `az ad app create` then read `appId` | `.github/workflows/bootstrap.yml`, `.github/workflows/deploy.yml` |
| `AZURE_TENANT_ID` | Secret | Microsoft Entra tenant ID | `az account show --query tenantId -o tsv` | `.github/workflows/bootstrap.yml`, `.github/workflows/deploy.yml` |
| `AZURE_SUBSCRIPTION_ID` | Secret | Azure subscription ID | `az account show --query id -o tsv` | `.github/workflows/bootstrap.yml`, `.github/workflows/deploy.yml` |
| `DB_PASSWORD` | Secret | Production database password injected into ACA secret store | Existing production credential source | `infra/main.bicepparam` (via environment variable), `infra/main.bicep` |
| `JWT_SECRET` | Secret | JWT signing secret injected into ACA secret store | Existing production credential source | `infra/main.bicepparam` (via environment variable), `infra/main.bicep` |
| `MQTT_PASSWORD` | Secret | MQTT broker password injected into ACA secret store | Existing production credential source | `infra/main.bicepparam` (via environment variable), `infra/main.bicep` |
| `OWM_API_KEY` | Secret | OpenWeather API key injected into ACA secret store | OpenWeather account/API key | `infra/main.bicepparam` (via environment variable), `infra/main.bicep` |
| `SMTP_PASSWORD` | Secret | SMTP password/API key injected into ACA secret store | Mail provider credential source | `infra/main.bicepparam` (via environment variable), `infra/main.bicep` |
| `SERVICE_BUS_CONNECTION` | Secret | Azure Service Bus connection string injected into ACA secret store | `az servicebus namespace authorization-rule keys list ...` | `infra/main.bicepparam` (via environment variable), `infra/main.bicep` |
| `ACR_NAME` | Variable | Short Azure Container Registry name (no suffix) | Output from `az deployment sub create` (`acrName`) | `.github/workflows/deploy.yml` |
| `ACR_LOGIN_SERVER` | Variable | Full ACR login server (`<name>.azurecr.io`) | Output from `az deployment sub create` (`acrLoginServer`) | `.github/workflows/deploy.yml` |
| `AZURE_RESOURCE_GROUP` | Variable | Production resource group name | Output from `az deployment sub create` (`resourceGroupName`) | `.github/workflows/deploy.yml` |
| `AZURE_REGION` | Variable | Deployment region (example `eastus`) | Chosen target region | `.github/workflows/bootstrap.yml`, `.github/workflows/deploy.yml` |

## OIDC App Registration and Federated Credential

```bash
export APP_NAME="agriwizard-github-oidc-prod"
export GITHUB_ORG="<github-org-or-user>"
export GITHUB_REPO="<repo-name>"
export SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
export TENANT_ID="$(az account show --query tenantId -o tsv)"

APP_ID="$(az ad app create --display-name "${APP_NAME}" --query appId -o tsv)"
SP_ID="$(az ad sp create --id "${APP_ID}" --query id -o tsv)"

cat > /tmp/github-main-oidc.json <<EOF
{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}
EOF

az ad app federated-credential create \
  --id "${APP_ID}" \
  --parameters /tmp/github-main-oidc.json
```

## Role Assignment Commands

```bash
export SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
export ACR_NAME="<acr-name>"
export APP_ID="<app-client-id>"
SP_ID="$(az ad sp show --id "${APP_ID}" --query id -o tsv)"
ACR_ID="$(az acr show --name "${ACR_NAME}" --query id -o tsv)"

# Subscription-wide infra provisioning permissions
az role assignment create \
  --assignee-object-id "${SP_ID}" \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "/subscriptions/${SUBSCRIPTION_ID}"

# Image push permissions for CI builds
az role assignment create \
  --assignee-object-id "${SP_ID}" \
  --assignee-principal-type ServicePrincipal \
  --role "AcrPush" \
  --scope "${ACR_ID}"
```
