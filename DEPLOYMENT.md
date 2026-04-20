# AgriWizard Production Deployment Guide

## Prerequisites

Before deploying, ensure you have:

1. **Azure Subscription** - Active Azure subscription
2. **Azure CLI** - Installed and configured
3. **GitHub Repository** - Access to AgriWizard repository
4. **Terraform** - Version 1.9.0 or later (if running locally)

---

## Step 1: Configure Azure Credentials

### Option A: GitHub Actions (Recommended)

1. Go to **Azure Portal** → **Azure Active Directory** → **App registrations**
2. Create new registration:
   - Name: `AgriWizard-Deploy`
   - Supported account types: Single tenant
3. Note the `Application (client) ID` and `Directory (tenant) ID`
4. Go to **Certificates & secrets** → New client secret:
   - Description: `GitHub Actions`
   - Expires: Custom (set to 1 year)
5. Note the `Client secret` value
6. Go to **Subscriptions** → Your subscription → **Access control (IAM)**
7. Add role assignment:
   - Role: `Contributor`
   - Assign access to: `Service principal`
   - Select: `AgriWizard-Deploy`

### Option B: Local Development

```bash
az login
az account set --subscription "<your-subscription-id>"
```

---

## Step 2: Configure GitHub Secrets

Navigate to GitHub repository → **Settings** → **Secrets and variables** → **Actions**

Create these secrets:

| Secret Name | Value |
|-------------|-------|
| `AZURE_CREDENTIALS` | JSON from Step 3 below |
| `AZURE_CLIENT_ID` | Application (client) ID from Step 1 |
| `AZURE_CLIENT_SECRET` | Client secret from Step 1 |
| `AZURE_SUBSCRIPTION_ID` | Your Azure subscription ID |
| `AZURE_TENANT_ID` | Directory (tenant) ID from Step 1 |
| `ACR_USERNAME` | `agriwizardacr` |
| `ACR_PASSWORD` | ACR admin password |
| `TERRAFORM_BACKEND_STORAGE_ACCOUNT` | Storage account for TF state |
| `TERRAFORM_BACKEND_STORAGE_KEY` | Storage account key |
| `TERRAFORM_BACKEND_CONTAINER` | `terraform` |
| `TERRAFORM_BACKEND_RESOURCE_GROUP` | `agriwizard-rg` |

**To get `AZURE_CREDENTIALS`:**

```bash
az ad sp create-for-rbac --name "AgriWizard-Deploy" --role contributor \
  --scopes /subscriptions/<subscription-id>/resourceGroups/agriwizard-rg
```

---

## Step 3: Create Azure Resource Group

```bash
az group create --name agriwizard-rg --location centralindia
```

---

## Step 4: Create Terraform Backend Storage

```bash
# Create storage account (must be unique name)
az storage account create --name agriwizardstf \
  --resource-group agriwizard-rg \
  --location centralindia \
  --sku Standard_LRS

# Create container
az storage container create --name terraform \
  --account-name agriwizardstf
```

---

## Step 5: Configure PostgreSQL

The PostgreSQL flexible server will be created by Terraform. Ensure:
- Password is at least 12 characters
- Use strong password in `prod.tfvars`

---

## Step 6: Update prod.tfvars

Edit `terraform/prod.tfvars` with your values:

```hcl
# Required: Update these
postgresql_admin_password = "YourSecurePassword@123"
jwt_secret = "YourJWTSecret-minimum-32-characters"
rabbitmq_default_pass = "YourRabbitMQPassword@123"
```

---

## Step 7: Deploy via GitHub Actions

### Automatic Deployment (Recommended)

1. **Push to main branch:**

```bash
git checkout main
git merge development
git push origin main
```

2. **Or create a version tag:**

```bash
git tag v1.0.0
git push origin v1.0.0
```

### Manual Deployment

1. Go to GitHub → **Actions** → **Deploy to Azure**
2. Click **Run workflow**
3. Select environment: `production`
4. Click **Run workflow**

---

## Step 8: Verify Deployment

### Check Container Apps

```bash
# Check all container apps
az containerapp list -g agriwizard-rg -o table

# Check specific service
az containerapp show -n agriwizard-iam -g agriwizard-rg --query properties.provisioningState
```

### Check Terraform Output

```bash
cd terraform
terraform output
```

### Access Services

| Service | URL |
|---------|-----|
| Kong Gateway | `http://<kong-fqdn>:8000` |
| Kong Admin | `http://<kong-fqdn>:8001` |
| RabbitMQ Management | `http://<rabbitmq-mgmt-fqdn>:15672` |

---

## Step 9: Update Kong Configuration (First Deploy Only)

The Kong declarative config needs to be applied after services are running:

```bash
# Get Kong admin URL
KONG_ADMIN=$(az containerapp show -n agriwizard-kong -g agriwizard-rg --query properties.fqdn -o tsv)

# Apply Kong configuration
curl -X POST http://${KONG_ADMIN}:8001/config \
  -F config=@terraform/kong-config/kong.yml
```

---

## Troubleshooting

### Container App Not Starting

```bash
# Check logs
az containerapp logs show -n agriwizard-iam -g agriwizard-rg --tail 100
```

### Terraform State Lock

```bash
# Force unlock
terraform force-unlock <lock-id>
```

### Image Pull Errors

```bash
# Check ACR credentials
az acr credential show -n agriwizardacr
```

---

## Deployment Flow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   GitHub    │───▶│   Azure    │───▶│  Services  │
│   Push     │    │   ACI      │    │   Running  │
└─────────────┘    └─────────────┘    └─────────────┘
      │                  │                   │
      ▼                  ▼                   ▼
  main branch      Terraform          Container Apps
  or v* tag         Apply              + Kong
                                       + RabbitMQ
                                       + PostgreSQL
```

---

## Quick Commands

```bash
# Login to ACR
az acr login -n agriwizardacr

# List running services
az containerapp list -g agriwizard-rg --query "[].{Name:name,Status:properties.provisioningState}" -o table

# Restart a service
az containerapp restart -n agriwizard-iam -g agriwizard-rg

# Scale a service
az containerapp update -n agriwizard-iam -g agriwizard-rg --min-replicas 2 --max-replicas 10
```