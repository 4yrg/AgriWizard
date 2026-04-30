#!/bin/bash
# =============================================================================
# AgriWizard Azure Bootstrap Script
# =============================================================================
# Creates OIDC identity for GitHub Actions and outputs required secrets.
# Run this once to set up Azure credentials.
# =============================================================================

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────
APP_NAME="agriwizard-github-oidc"
GITHUB_ORG="${GITHUB_ORG:-}"
GITHUB_REPO="${GITHUB_REPO:-}"
AZURE_REGION="${AZURE_REGION:-centralindia}"

# ── Colors ────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ── Validate ────────────────────────────────────────────────────────────────
if [ -z "${GITHUB_ORG}" ] || [ -z "${GITHUB_REPO}" ]; then
    echo "Usage: GITHUB_ORG=<org> GITHUB_REPO=<repo> ./scripts/bootstrap-azure.sh"
    echo ""
    echo "Example: GITHUB_ORG=myorg GITHUB_REPO=AgriWizard ./scripts/bootstrap-azure.sh"
    exit 1
fi

# ── Check Azure CLI ────────────────────────────────────────────────────────
if ! command -v az &> /dev/null; then
    log_error "Azure CLI not found. Install with: brew install azure-cli"
    exit 1
fi

# ── Login Check ────────────────────────────────────────────────────────────
log_info "Checking Azure login..."
az account show &> /dev/null || { log_error "Not logged in. Run 'az login' first."; exit 1; }

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

log_info "Subscription: ${SUBSCRIPTION_ID}"
log_info "Tenant: ${TENANT_ID}"
log_info "Region: ${AZURE_REGION}"

# ── Create Resource Group ─────────────────────────────────────────────────
RG_NAME="agriwizard-prod-rg"
log_info "Creating resource group: ${RG_NAME}"

if az group show --name "${RG_NAME}" &> /dev/null; then
    log_warn "Resource group already exists"
else
    az group create --name "${RG_NAME}" --location "${AZURE_REGION}" --output none
    log_info "Resource group created"
fi

# ── Create App Registration ────────────────────────────────────────────────
log_info "Creating Azure AD app registration: ${APP_NAME}"

# Check if app already exists
APP_ID=$(az ad app list --display-name "${APP_NAME}" --query '[0].appId' -o tsv 2>/dev/null || true)

if [ -z "${APP_ID}" ]; then
    APP_ID=$(az ad app create --display-name "${APP_NAME}" --query appId -o tsv)
    log_info "App registration created: ${APP_ID}"
else
    log_warn "App registration already exists: ${APP_ID}"
fi

# Create service principal
log_info "Creating service principal..."
SP_ID=$(az ad sp create --id "${APP_ID}" --query id -o tsv)
log_info "Service principal created: ${SP_ID}"

# ── Create Federated Credential ────────────────────────────────────────────
log_info "Creating federated credential for GitHub Actions..."

CRED_NAME="github-main-${GITHUB_REPO}"
CRED_EXISTS=$(az ad app federated-credential list --id "${APP_ID}" --query "[?name=='${CRED_NAME}'].name" -o tsv || true)

if [ -n "${CRED_EXISTS}" ]; then
    log_warn "Federated credential already exists, skipping creation"
else
    cat > /tmp/federated-credential.json <<EOF
{
  "name": "${CRED_NAME}",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}
EOF
    az ad app federated-credential create --id "${APP_ID}" --parameters /tmp/federated-credential.json
    rm /tmp/federated-credential.json
    log_info "Federated credential created"
fi

# ── Role Assignment: Contributor (Subscription) ───────────────────────────
log_info "Assigning Contributor role at subscription scope..."
ROLE_EXISTS=$(az role assignment list --assignee "${SP_ID}" --role "Contributor" --scope "/subscriptions/${SUBSCRIPTION_ID}" --query '[0].id' -o tsv 2>/dev/null || true)

if [ -z "${ROLE_EXISTS}" ]; then
    az role assignment create \
        --assignee-object-id "${SP_ID}" \
        --assignee-principal-type ServicePrincipal \
        --role "Contributor" \
        --scope "/subscriptions/${SUBSCRIPTION_ID}" \
        --output none
    log_info "Contributor role assigned"
else
    log_warn "Contributor role already assigned"
fi

# ── Role Assignment: AcrPush (Will be assigned after ACR is created) ───────
# This will be done during first infrastructure deployment

# ── Output Secrets ─────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "                    GITHUB SECRETS TO ADD"
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo "Add these as Repository Secrets (Settings → Secrets → Actions):"
echo ""
echo -e "${GREEN}AZURE_CLIENT_ID${NC}   = ${APP_ID}"
echo -e "${GREEN}AZURE_TENANT_ID${NC}   = ${TENANT_ID}"
echo -e "${GREEN}AZURE_SUBSCRIPTION_ID${NC} = ${SUBSCRIPTION_ID}"
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "                    GITHUB VARIABLES TO ADD"
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo "Add these as Repository Variables (Settings → Variables → Actions):"
echo ""
echo -e "${GREEN}AZURE_REGION${NC} = ${AZURE_REGION}"
echo ""
echo "After running the bootstrap workflow, add these from the workflow output:"
echo "  - ACR_NAME"
echo "  - ACR_LOGIN_SERVER"
echo "  - AZURE_RESOURCE_GROUP_PRODUCTION"
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "                    NEXT STEPS"
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo "1. Add the 3 secrets above to GitHub"
echo "2. Run the 'Bootstrap Production Infrastructure' workflow manually"
echo "3. From the workflow output, copy ACR_NAME, ACR_LOGIN_SERVER, AZURE_RESOURCE_GROUP"
echo "4. Add those as GitHub variables"
echo "5. Add additional secrets: DB_PASSWORD, JWT_SECRET, OWM_API_KEY, MQTT_PASSWORD, SMTP_PASSWORD, SERVICE_BUS_CONNECTION"
echo "6. Push to main to trigger deployment"
echo ""