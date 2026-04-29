#!/bin/bash
set -e

# AgriWizard Azure Bootstrap Script
# Sets up OIDC and initial infrastructure

RG_NAME=${1:-"agriwizard-prod-rg"}
LOCATION=${2:-"centralindia"}
GH_REPO=${3:-"your-org/your-repo"}

echo "Creating Resource Group: $RG_NAME in $LOCATION"
az group create --name "$RG_NAME" --location "$LOCATION"

# Create Identity for GitHub Actions
ID_NAME="agriwizard-github-actions-id"
echo "Creating User Assigned Identity: $ID_NAME"
az identity create --name "$ID_NAME" --resource-group "$RG_NAME"

CLIENT_ID=$(az identity show --name "$ID_NAME" --resource-group "$RG_NAME" --query "clientId" -o tsv)
TENANT_ID=$(az account show --query "tenantId" -o tsv)
SUB_ID=$(az account show --query "id" -o tsv)

echo "Assigning Contributor role to Identity"
az role assignment create --assignee "$CLIENT_ID" --role "Contributor" --scope "/subscriptions/$SUB_ID/resourceGroups/$RG_NAME"

# Setup Federated Credential
echo "Setting up Federated Identity for GitHub Actions..."
az identity federated-credential create \
  --name "AgriWizardProdBranch" \
  --identity-name "$ID_NAME" \
  --resource-group "$RG_NAME" \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:$GH_REPO:ref:refs/heads/main"

echo "----------------------------------------------------"
echo "GITHUB SECRETS TO ADD:"
echo "AZURE_CLIENT_ID: $CLIENT_ID"
echo "AZURE_TENANT_ID: $TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID: $SUB_ID"
echo "----------------------------------------------------"
