# AgriWizard — Azure Deployment Guide

This guide walks through deploying AgriWizard to Azure using Terraform.

---

## Prerequisites

| Requirement | Version | Notes |
|------------|---------|-------|
| Azure CLI | 2.50+ | `az --version` |
| Terraform | 1.0+ | `terraform --version` |
| Git | Any | For cloning |
| Docker | 24+ | For building images |

### Required Permissions

| Role | Scope |
|------|-------|
| Contributor | Subscription or Resource Group |
| Key Vault Contributor | Key Vault (if using RBAC) |

---

## Step 1: Clone and Setup

```bash
# Clone repository
git clone https://github.com/agriwizard/agriwizard.git
cd agriwizard

# Navigate to Terraform
cd infrastructure/azure/terraform
```

---

## Step 2: Authenticate to Azure

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "Your-Subscription-Name"

# Verify
az account show --output table
```

---

## Step 3: Create Backend Storage (Terraform State)

This creates a separate resource group for Terraform state storage in your approved region.

### 3.1 Create Resource Group

```bash
# Variables - use centralindia as approved region
RG="agriwizard-tf-rg"
LOCATION="centralindia"

# Create resource group
az group create --name $RG --location $LOCATION
```

### 3.2 Create Storage Account

```bash
# Generate unique name (must be globally unique, 3-24 lowercase chars)
SUFFIX=$(date +%s | tail -c 5)
STORAGE_NAME="tfstate${SUFFIX}"

# Create storage account
az storage account create \
  --name $STORAGE_NAME \
  --resource-group $RG \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2

# Verify
az storage account show --name $STORAGE_NAME --resource-group $RG --query provisioningState
```

### 3.3 Create Blob Container

```bash
# Create container with Azure AD authentication
az storage container create \
  --name tfstate \
  --account-name $STORAGE_NAME \
  --auth-mode login \
  --public-access off
```

### 3.4 Grant Access (RBAC)

```bash
# Get current user ID
USER_ID=$(az ad signed-in-user show --query id -o tsv)

# Assign Storage Blob Data Contributor role
az role assignment create \
  --assignee $USER_ID \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${RG}/providers/Microsoft.Storage/storageAccounts/${STORAGE_NAME}"
```

### 3.5 Create backend.tf

Create `backend.tf` in `infrastructure/azure/terraform/`:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "agriwizard-tf-rg"
    storage_account_name = "tfstateXXXXX"
    container_name       = "tfstate"
    key                  = "agriwizard/dev/terraform.tfstate"
    use_azuread_auth    = true
  }
}
```

Replace `tfstateXXXXX` with your actual storage account name from Step 3.2.

### 3.6 Multi-Environment State Keys

For multiple environments, use different keys:

| Environment | State Key |
|-------------|-----------|
| Dev | `agriwizard/dev/terraform.tfstate` |
| Staging | `agriwizard/staging/terraform.tfstate` |
| Prod | `agriwizard/prod/terraform.tfstate` |

Update `backend.tf` per environment or use workspaces.

---

## Step 4: Initialize Terraform

```bash
# Navigate to Terraform directory
cd infrastructure/azure/terraform

# Initialize providers (uses backend.tf)
terraform init

# Verify
terraform version
```

Expected output:
```
Terraform v1.x.x
```

> **Note**: If you skipped Step 3, initialize without backend first:
> ```bash
> terraform init -backend=false
> ```
> Then configure backend manually.

---

## Step 5: Plan Deployment

```bash
# Plan for development environment
terraform plan \
  -var-file=environments/dev.tfvars \
  -out=dev.tfplan
```

Review the plan output - it should show:

```
Plan: 15 to add, 0 to change, 0 to destroy.
```

---

## Step 6: Deploy Infrastructure

```bash
# Apply development environment
terraform apply dev.tfplan
```

This will create:

| Resource | Name | Type |
|----------|------|------|
| Resource Group | agriwizard-dev-rg | Resource Group |
| Log Analytics | agriwizard-dev-law | Log Analytics |
| App Insights | agriwizard-dev-ai | Application Insights |
| PostgreSQL | agriwizard-dev-postgres | Azure Database for PostgreSQL |
| Key Vault | agriwizard-dev-kv | Key Vault |
| Service Bus | agriwizard-dev-sbns | Service Bus |
| Container Apps Env | agriwizard-dev-aca | Container Apps Environment |
| Kong API Gateway | agriwizard-dev-kong | Container App (API Gateway) |
| HiveMQ Broker | agriwizard-dev-hivemq | Container App (MQTT Broker) |
| 6 Container Apps | iam, hardware, analytics, weather, notification, frontend | Container Apps |
| Storage | agriwizarddevst | Blob Storage |

Expected time: **15-20 minutes**

---

## Step 7: Verify Deployment

```bash
# Check resource group
az group show --name agriwizard-dev-rg --output table

# List all resources
az resource list \
  --resource-group agriwizard-dev-rg \
  --output table
```

### Required Outputs

```bash
# Get important values
terraform output

# Container Registry
az acr list -g agriwizard-dev-rg --output table

# Container Apps
az containerapp list -g agriwizard-dev-rg --output table
```

---

## Step 8: Build and Push Images

```bash
# Get registry name
ACR_NAME=$(az acr list -g agriwizard-dev-rg --query '[0].name' -o tsv)
echo "Registry: $ACR_NAME"

# Login to ACR
az acr login --name $ACR_NAME

# Build and push backend services
for service in iam-service hardware-service analytics-service weather-service notification-service; do
  echo "Building $service..."
  
  az acr build \
    --registry $ACR_NAME \
    --image agriwizard-${service}:latest \
    --file ../../services/${service}/Dockerfile \
    ../../.
done

# Build and push frontend
echo "Building frontend..."
az acr build \
  --registry $ACR_NAME \
  --image agriwizard-frontend:latest \
  --file ../../client/Dockerfile \
  ../../.
```

---

## Step 9: Deploy Images to Container Apps

```bash
# Update each container app with new image
for service in kong hivemq iam hardware analytics weather notification frontend; do
  echo "Updating ${service}..."
  
  az containerapp update \
    --name agriwizard-dev-${service} \
    --resource-group agriwizard-dev-rg \
    --image ${ACR_NAME}.azurecr.io/agriwizard-${service}:latest
done
```

---

## Step 10: Test Deployment

```bash
# Get Kong gateway URL
KONG_URL=$(az containerapp show \
  --name agriwizard-dev-kong \
  --resource-group agriwizard-dev-rg \
  --query "properties.provisioningState" -o tsv)

# Get frontend URL
FRONTEND_URL=$(az containerapp show \
  --name agriwizard-dev-frontend \
  --resource-group agriwizard-dev-rg \
  --query "properties.configuration.ingress.fqdn" -o tsv)

echo "Frontend: https://${FRONTEND_URL}"

# Test Kong health
curl -f http://${KONG_URL}:8080/health || echo "Kong health check failed"

# Test IAM service through Kong
curl -f http://${KONG_URL}:8080/api/v1/iam/health || echo "IAM failed"
```

---

## Infrastructure Details

### Kong API Gateway
- **Port**: 8080 (HTTP external)
- **Admin API**: 8001
- **Purpose**: API gateway for all backend services
- **Routes**: `/api/v1/iam/*`, `/api/v1/hardware/*`, `/api/v1/analytics/*`, `/api/v1/weather/*`

### HiveMQ MQTT Broker
- **MQTT Port**: 1883 (TCP external)
- **WebSocket Port**: 8083 (WS external)
- **Purpose**: IoT device communication
- **Protocol**: MQTT 3.1.1 and 5.0

### Backend Services

| Service | Port | Database | Description |
|--------|------|----------|-------------|
| IAM | 8086 | PostgreSQL | Identity & Access Management |
| Hardware | 8087 | PostgreSQL | Equipment & Sensor Management |
| Analytics | 8088 | PostgreSQL | Data Analysis & Thresholds |
| Weather | 8089 | - | Weather Service (mock) |
| Notification | 8091 | PostgreSQL | Push Notifications |

### Frontend
- **Port**: 3000
- **Framework**: Next.js
- **API URL**: Points to Kong Gateway

---

## Common Commands

### View Logs

```bash
# Container app logs
az containerapp logs show \
  --name agriwizard-dev-iam \
  --resource-group agriwizard-dev-rg \
  --tail 100

# Follow logs
az containerapp logs show \
  --name agriwizard-dev-iam \
  --resource-group agriwizard-dev-rg \
  --follow
```

### Scale Services

```bash
# Manual scale
az containerapp update \
  --name agriwizard-dev-iam \
  --resource-group agriwizard-dev-rg \
  --min-replicas 2 \
  --max-replicas 5

# Enable scale to zero
az containerapp update \
  --name agriwizard-dev-weather \
  --resource-group agriwizard-dev-rg \
  --min-replicas 0
```

### Restart Service

```bash
az containerapp restart \
  --name agriwizard-dev-iam \
  --resource-group agriwizard-dev-rg
```

### Get Connection Strings

```bash
# PostgreSQL
az postgres flexible-server show \
  -n agriwizard-dev-postgres \
  -g agriwizard-dev-rg \
  --query "fullyQualifiedDomainName"

# Service Bus
az servicebus namespace show \
  -n agriwizard-dev-sbns \
  -g agriwizard-dev-rg \
  --query "defaultPrimaryConnectionString"

# Get Kong Admin URL
KONG_ADMIN=$(az containerapp show \
  --name agriwizard-dev-kong \
  --resource-group agriwizard-dev-rg \
  --query "properties.configuration.ingress.fqdn" -o tsv)
echo "http://${KONG_ADMIN}:8001"
```

---

## Troubleshooting

### Terraform Issues

| Error | Solution |
|-------|----------|
| Provider not initialized | Run `terraform init` |
| State locked | `terraform force-unlock <lock-id>` |
| Variable not found | Check `.tfvars` file exists |

### Container App Issues

| Error | Solution |
|-------|----------|
| Image pull failure | Check ACR login and image exists |
| Container crash | Check logs: `az containerapp logs show` |
| Port not exposed | Update `target_port` in config |

### Kong Issues

| Error | Solution |
|-------|----------|
| 404 on routes | Check Kong declarative config |
| Admin not accessible | Check ingress port 8001 |

### HiveMQ Issues

| Error | Solution |
|-------|----------|
| MQTT connection failed | Check port 1883 is exposed |
| WebSocket failed | Check port 8083 is exposed |

---

## Cleanup

### Destroy Terraform Infrastructure

```bash
# Destroy development environment
terraform destroy -var-file=environments/dev.tfvars

# Confirm with "yes"
```

### Remove Just Container Apps

```bash
# Delete container apps only (keep infrastructure)
for service in kong hivemq iam hardware analytics weather notification frontend; do
  az containerapp delete \
    --name agriwizard-dev-${service} \
    --resource-group agriwizard-dev-rg \
    --yes
done
```

### Destroy Terraform Backend (Optional)

> **Warning**: This deletes all Terraform state. Only do this if you want to completely remove Terraform-managed infrastructure.

```bash
# Delete the entire terraform state resource group
az group delete --name agriwizard-tf-rg --yes --no-wait
```

---

## Next Steps

1. **Configure DNS** - Point your domain to Kong gateway
2. **Set up CI/CD** - Use GitHub Actions workflow
3. **Add secrets to Key Vault** - Database passwords, API keys
4. **Configure monitoring** - Set up alerts in App Insights
5. **Scale production** - Update to `prod.tfvars`

---

## Quick Reference

```bash
# Full deployment sequence
 az login
 cd infrastructure/azure/terraform
 terraform init
 terraform plan -var-file=environments/dev.tfvars -out=dev.tfplan
 terraform apply dev.tfplan
 ACR_NAME=$(az acr list -g agriwizard-dev-rg --query '[0].name' -o tsv)
 az acr login --name $ACR_NAME
 # Build and push images (Step 8)
 # Deploy to Container Apps (Step 9)
 # Test (Step 10)
```

---

## Terraform File Structure

```
infrastructure/azure/terraform/
├── api-messaging.tf     # Kong, HiveMQ, backend containers
├── backend.tf           # Terraform state storage
├── database.tf          # Azure PostgreSQL Flexible Server
├── key-vault.tf         # Key Vault
├── outputs.tf           # Output values
├── resource-group.tf    # RG, Log Analytics, App Insights
├── service-bus.tf       # Azure Service Bus
├── storage.tf          # Storage account
├── variables.tf         # Variables
└── versions.tf           # Provider versions
```