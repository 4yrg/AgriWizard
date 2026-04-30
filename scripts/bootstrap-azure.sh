#!/bin/bash
# =============================================================================
# AgriWizard Azure Bootstrap Script (Managed Identity Version)
# =============================================================================
# Creates a User-Assigned Managed Identity for GitHub Actions OIDC.
# Run this once to set up Azure credentials.
# =============================================================================

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────
ID_NAME="agriwizard-github-oidc-id"
GITHUB_ORG="${GITHUB_ORG:-}"
GITHUB_REPO="${GITHUB_REPO:-}"
AZURE_REGION="${AZURE_REGION:-centralindia}"
RG_NAME="agriwizard-prod-rg"

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
log_info "Ensuring resource group exists: ${RG_NAME}"

if az group show --name "${RG_NAME}" &> /dev/null; then
    log_warn "Resource group already exists"
else
    az group create --name "${RG_NAME}" --location "${AZURE_REGION}" --output none
    log_info "Resource group created"
fi

# ── Create Managed Identity ────────────────────────────────────────────────
log_info "Creating Managed Identity: ${ID_NAME}"

# Check if identity already exists
CLIENT_ID=$(az identity show --name "${ID_NAME}" --resource-group "${RG_NAME}" --query clientId -o tsv 2>/dev/null || true)

if [ -z "${CLIENT_ID}" ]; then
    CLIENT_ID=$(az identity create --name "${ID_NAME}" --resource-group "${RG_NAME}" --query clientId -o tsv)
    log_info "Managed Identity created: ${CLIENT_ID}"
else
    log_warn "Managed Identity already exists: ${CLIENT_ID}"
fi

PRINCIPAL_ID=$(az identity show --name "${ID_NAME}" --resource-group "${RG_NAME}" --query principalId -o tsv)

# ── Create Federated Credential ────────────────────────────────────────────
log_info "Creating federated credential for GitHub Actions..."

CRED_NAME="github-main-${GITHUB_REPO}"
CRED_EXISTS=$(az identity federated-credential list --identity-name "${ID_NAME}" --resource-group "${RG_NAME}" --query "[?name=='${CRED_NAME}'].name" -o tsv || true)

if [ -n "${CRED_EXISTS}" ]; then
    log_warn "Federated credential already exists, skipping creation"
else
    az identity federated-credential create \
      --name "${CRED_NAME}" \
      --identity-name "${ID_NAME}" \
      --resource-group "${RG_NAME}" \
      --issuer "https://token.actions.githubusercontent.com" \
      --subject "repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main" \
      --audience "api://AzureADTokenExchange" \
      --output none
    log_info "Federated credential created"
fi

# ── Role Assignment: Owner (On Resource Group) ───────────────────────────
# We use Owner on the RG so it can manage Role Assignments for the apps
log_info "Assigning Owner role on resource group..."
az role assignment create \
    --assignee "${PRINCIPAL_ID}" \
    --role "Owner" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}" \
    --output none
log_info "Owner role assigned"

# ── Role Assignment: Contributor (Subscription) ───────────────────────────
log_info "Assigning Contributor role at subscription scope..."
az role assignment create \
    --assignee "${PRINCIPAL_ID}" \
    --role "Contributor" \
    --scope "/subscriptions/${SUBSCRIPTION_ID}" \
    --output none
log_info "Contributor role assigned"

# ── Output Secrets ─────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "                    GITHUB SECRETS TO ADD"
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo "Add these as Repository Secrets (Settings → Secrets → Actions):"
echo ""
echo -e "${GREEN}AZURE_CLIENT_ID${NC}   = ${CLIENT_ID}"
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
echo "═══════════════════════════════════════════════════════════════════════"
echo "                    NEXT STEPS"
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo "1. Add the 3 secrets above to GitHub"
echo "2. Push to main to trigger deployment"
echo ""