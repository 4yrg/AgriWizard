# AgriWizard Azure Deployment Guide

## Prerequisites

- Azure Subscription
- Azure CLI installed
- Terraform installed (v1.0+)
- Docker installed
- Git

---

## Step 1: Authenticate with Azure

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "<your-subscription-id>"

# Verify login
az account show
```

---

## Step 2: Create Resource Group (if not exists)

```bash
az group create --name AgriWizard --location centralindia
```

---

## Step 3: Initialize Terraform

```bash
cd terraform

# Initialize Terraform backend
terraform init

# Create a terraform.tfvars file with your values
cat > terraform.tfvars << EOF
environment                = "prod"
postgresql_admin_password  = "YourSecurePassword123!"
jwt_secret                 = "your-32-character-minimum-jwt-secret-key"
apim_publisher_email       = "admin@agriwizard.com"
EOF
```

---

## Step 4: Deploy Infrastructure

```bash
# Preview the changes
terraform plan -var-file=terraform.tfvars

# Apply the changes
terraform apply -var-file=terraform.tfvars
```

This will create:
- Azure Container Registry (ACR)
- Azure Container Apps Environment
- Azure PostgreSQL Flexible Server
- Azure IoT Hub
- Azure API Management
- Azure Service Bus (with 3 topics)
- Azure Key Vault
- Application Insights
- Log Analytics Workspace

---

## Step 5: Build and Push Docker Images

### 5.1 Login to ACR

```bash
# Get ACR credentials
az acr login --name agriwizardacr

# Or using admin credentials
docker login agriwizardacr.azurecr.io -u <admin-username> -p <admin-password>
```

### 5.2 Build and Push Each Service

```bash
# Set image tag
export IMAGE_TAG="v1.0.0"
export ACR="agriwizardacr.azurecr.io"

# IAM Service
cd services/iam-service
docker build -t $ACR/agriwizard-iam-service:$IMAGE_TAG .
docker push $ACR/agriwizard-iam-service:$IMAGE_TAG

# Hardware Service
cd ../hardware-service
docker build -t $ACR/agriwizard-hardware-service:$IMAGE_TAG .
docker push $ACR/agriwizard-hardware-service:$IMAGE_TAG

# Analytics Service
cd ../analytics-service
docker build -t $ACR/agriwizard-analytics-service:$IMAGE_TAG .
docker push $ACR/agriwizard-analytics-service:$IMAGE_TAG

# Weather Service
cd ../weather-service
docker build -t $ACR/agriwizard-weather-service:$IMAGE_TAG .
docker push $ACR/agriwizard-weather-service:$IMAGE_TAG

# Notification Service
cd ../notification-service
docker build -t $ACR/agriwizard-notification-service:$IMAGE_TAG .
docker push $ACR/agriwizard-notification-service:$IMAGE_TAG
```

---

## Step 6: Update Container Apps with Correct Image Tags

```bash
# Update the image tag in Terraform
cd terraform

# Edit variables.tf or terraform.tfvars to set the image tag
echo 'image_tag = "v1.0.0"' >> terraform.tfvars

# Apply to update container apps
terraform apply -var-file=terraform.tfvars
```

---

## Step 7: Configure Service Bus Topics

The Terraform already creates the topics and subscriptions. Verify:

```bash
# List Service Bus topics
az servicebus topic list \
  --resource-group AgriWizard \
  --namespace-name agriwizard-sb

# List subscriptions
az servicebus subscription list \
  --resource-group AgriWizard \
  --namespace-name agriwizard-sb \
  --topic-name telemetry-events
```

---

## Step 8: Configure API Management

### 8.1 Get APIM URL

```bash
az apim show \
  --resource-group AgriWizard \
  --name agriwizard-apim \
  --query "gatewayURL" -o tsv
```

### 8.2 Get Subscription Keys

```bash
# List subscriptions
az apim subscription list \
  --resource-group AgriWizard \
  --api-management-name agriwizard-apim
```

### 8.3 Create a Subscription (if needed)

```bash
az apim subscription create \
  --resource-group AgriWizard \
  --api-management-name agriwizard-apim \
  --subscription-id "agriwizard-primary" \
  --display-name "Primary Subscription" \
  --state "active"
```

---

## Step 9: Test the Deployment

### 9.1 Health Checks

```bash
# Replace with your APIM URL
export APIM_URL="https://agriwizard-apim.azure-api.net"

# Test IAM Service
curl -s $APIM_URL/api/v1/iam/health

# Test Hardware Service  
curl -s $APIM_URL/api/v1/hardware/health

# Test Analytics Service
curl -s $APIM_URL/api/v1/analytics/health

# Test Weather Service
curl -s $APIM_URL/api/v1/weather/health

# Test Notification Service
curl -s $APIM_URL/api/v1/notifications/health
```

### 9.2 Register a User

```bash
curl -X POST $APIM_URL/api/v1/iam/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@agriwizard.com",
    "password": "SecurePassword123!",
    "role": "admin"
  }'
```

### 9.3 Login and Get Token

```bash
curl -X POST $APIM_URL/api/v1/iam/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@agriwizard.com",
    "password": "SecurePassword123!"
  }'
```

Use the returned token for subsequent API calls:

```bash
export TOKEN="<your-jwt-token>"

# Test with Authorization header
curl -H "Authorization: Bearer $TOKEN" $APIM_URL/api/v1/iam/profile
```

---

## Step 10: Configure IoT Hub (Optional - For Device Communication)

### 10.1 Create IoT Device

```bash
az iot hub device-identity create \
  --hub-name agriwizard-iot \
  --device-id sensor-001
```

### 10.2 Get Connection String

```bash
az iot hub device-identity connection-string show \
  --hub-name agriwizard-iot \
  --device-id sensor-001
```

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Azure API Management (APIM)                         │
│                    https://agriwizard-apim.azure-api.net                  │
│                   JWT Validation + Rate Limiting                           │
└──────────────────────────┬──────────────────────────────────────────────────┘
                         │
      ┌──────────────────┼──────────────────┬──────────────────┐
      │                  │                  │                  │
      ▼                  ▼                  ▼                  ▼
┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│ IAM Service │   │Hardware Svc │   │Analytics Svc│   │ Weather Svc │
│   :8081     │   │   :8082    │   │   :8083     │   │   :8084     │
└─────────────┘   └─────────────┘   └─────────────┘   └─────────────┘
                                             │                  │
                                             ▼                  │
                                    ┌─────────────────┐        │
                                    │ Service Bus      │        │
                                    │ - telemetry      │◄───────┘
                                    │ - automation     │
                                    │ - notifications  │
                                    └─────────────────┘
                                             │
      ┌──────────────────────────────────────┼──────────────────────┐
      │                                      │                      │
      ▼                                      ▼                      ▼
┌─────────────┐                     ┌─────────────────┐   ┌─────────────────┐
│ IoT Hub     │                     │Notification Svc │   │ PostgreSQL DB   │
│ (MQTT)      │                     │    :8085        │   │ Flexible Server │
└─────────────┘                     └─────────────────┘   └─────────────────┘
```

---

## Environment Variables Reference

| Service | Variable | Description | Default |
|---------|----------|-------------|---------|
| All | `GIN_MODE` | Gin framework mode | `release` |
| IAM | `PORT` | HTTP port | `8081` |
| IAM | `DB_HOST` | PostgreSQL host | localhost |
| IAM | `JWT_SECRET` | JWT signing secret | (required) |
| Hardware | `PORT` | HTTP port | `8082` |
| Hardware | `SERVICE_BUS_CONNECTION` | Service Bus connection string | (optional) |
| Hardware | `MQTT_BROKER` | MQTT broker URL | HiveMQ Cloud |
| Analytics | `PORT` | HTTP port | `8083` |
| Analytics | `SERVICE_BUS_CONNECTION` | Service Bus connection string | (optional) |
| Weather | `PORT` | HTTP port | `8084` |
| Weather | `OWM_API_KEY` | OpenWeatherMap API key | (optional) |
| Notification | `PORT` | HTTP port | `8085` |
| Notification | `SERVICE_BUS_CONNECTION` | Service Bus connection string | (optional) |
| Notification | `NATS_URL` | NATS server URL | nats://localhost:4222 |

---

## Troubleshooting

### Check Container App Logs

```bash
# List container apps
az containerapp list --resource-group AgriWizard

# Get logs
az containerapp logs show \
  --resource-group AgriWizard \
  --name prod-iam-service \
  --tail 100
```

### Check Application Insights

```bash
# View metrics in Azure Portal
# Or query using CLI
az monitor app-insights query \
  --app agriwizard-prod-appinsights \
  --query "requests | take 10"
```

### Restart a Container App

```bash
az containerapp restart \
  --resource-group AgriWizard \
  --name prod-hardware-service
```

---

## Cleanup

```bash
# Destroy all resources (careful!)
terraform destroy -var-file=terraform.tfvars

# Or delete resource group manually
az group delete --name AgriWizard --yes --no-wait
```
