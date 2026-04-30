#!/usr/bin/env bash
set -euo pipefail

SUBSCRIPTION_ID="6ad80231-cdc5-4bd4-975a-68e9bb9c75b4"
TENANT_ID="44e3cf94-19c9-4e32-96c3-14f5bf01391a"
APP_NAME="agriwizard-github-oidc-prod"
GITHUB_ORG="4yrg"
GITHUB_REPO="AgriWizard"

echo "Finding existing app..."
APP_ID="$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv || true)"

if [ -z "${APP_ID}" ]; then
  echo "No app found. Creating app registration..."
  APP_ID="$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)"
fi

if [ -z "${APP_ID}" ]; then
  echo "APP_ID is empty. Likely insufficient Entra permissions." >&2
  exit 1
fi

echo "Ensuring service principal exists..."
SP_ID="$(az ad sp show --id "$APP_ID" --query id -o tsv 2>/dev/null || true)"
if [ -z "${SP_ID}" ]; then
  SP_ID="$(az ad sp create --id "$APP_ID" --query id -o tsv)"
fi

if [ -z "${SP_ID}" ]; then
  echo "SP_ID is empty. Cannot continue." >&2
  exit 1
fi

cat > /tmp/gh-main-oidc.json <<JSON
{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}
JSON

echo "Creating federated credential (may fail if it already exists)..."
az ad app federated-credential create --id "$APP_ID" --parameters /tmp/gh-main-oidc.json || true

echo "Assigning Contributor role at subscription scope..."
az role assignment create \
  --assignee-object-id "$SP_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID" || true

echo "AZURE_CLIENT_ID=$APP_ID"
echo "AZURE_TENANT_ID=$TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
