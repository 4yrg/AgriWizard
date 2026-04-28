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
| Azure Connected Machine | For onboarding |

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

## Step 3: Create Backend Storage (Optional)

If you want to store Terraform state remotely:

```bash
# Variables
RG="terraform-state-rg"
LOCATION="eastus"
STORAGE_NAME="terraformstate$(date +%s)"

# Create resource group
az group create --name $RG --location $LOCATION

# Create storage account
az storage account create \
  --name $STORAGE_NAME \
  --resource-group $RG \
  --sku Standard_LRS \
  --kind StorageV2

# Create blob container
az storage container create \
  --name tfstate \
  --account-name $STORAGE_NAME
```

Update `versions.tf`:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "terraformstatestorage"
    container_name     = "tfstate"
    key                = "agriwizard.tfstate"
  }
}
```

---

## Step 4: Initialize Terraform

```bash
# Initialize providers
terraform init

# Verify
terraform version
```

Expected output:
```
Terraform v1.x.x
```

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
| PostgreSQL | agriwizard-dev-postgres | Flexible Server |
| Key Vault | agriwizard-dev-kv | Key Vault |
| Service Bus | agriwizard-dev-sb | Service Bus |
| IoT Hub | agriwizard-dev-iothub | IoT Hub |
| Container Apps Env | agriwizard-dev-aca | Container Apps |
| 5 Container Apps | iam, hardware, analytics, weather, notification | Container Apps |
| API Management | agriwizard-dev-apim | API Management |
| Storage | agriwizarddevst | Blob Storage |

Expected time: **10-15 minutes**

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

# Build and push each service
for service in iam-service hardware-service analytics-service weather-service notification-service; do
  echo "Building $service..."
  
  az acr build \
    --registry $ACR_NAME \
    --image agriwizard-${service}:latest \
    --file ../../services/${service}/Dockerfile \
    ../../.
done
```

---

## Step 9: Deploy to Container Apps

```bash
# Update each container app with new image
for service in iam hardware analytics weather notification; do
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
# Get APIM gateway URL
APIM_URL=$(az apim show -n agriwizard-dev-apim -g agriwizard-dev-rg --query "gatewayUrl" -o tsv)
echo "Gateway: $APIM_URL"

# Test health endpoint
curl -f ${APIM_URL}/health || echo "Health check failed"

# Test IAM service
curl -f ${APIM_URL}/api/v1/iam/health || echo "IAM failed"
```

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

# IoT Hub
az iot hub connection-string show \
  -n agriwizard-dev-iothub \
  -g agriwizard-dev-rg

# Service Bus
az servicebus namespace show \
  -n agriwizard-dev-sb \
  -g agriwizard-dev-rg \
  --query "defaultPrimaryConnectionString"
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

### Network Issues

| Error | Solution |
|-------|----------|
| Cannot reach service | Check ingress is enabled |
| VNET issues | Verify subnet delegation |

---

## Cleanup

### Destroy Resources

```bash
# Destroy development environment
terraform destroy -var-file=environments/dev.tfvars

# Confirm with "yes"
```

### Remove Just Container Apps

```bash
# Delete container apps only (keep infrastructure)
for service in iam hardware analytics weather notification; do
  az containerapp delete \
    --name agriwizard-dev-${service} \
    --resource-group agriwizard-dev-rg \
    --yes
done
```

---

## Next Steps

1. **Configure DNS** - Point your domain to APIM gateway
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