# AgriWizard - Azure Container Apps Deployment Guide

This guide covers deploying all AgriWizard microservices to Azure Container Apps.

---

## 📋 Prerequisites

### 1. Azure CLI
```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login to Azure
az login

# Set subscription
az account set --subscription "<your-subscription-id>"
```

### 2. Register Required Providers
```bash
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights
```

---

## 🏗️ Infrastructure Setup

### 1. Create Resource Group
```bash
RESOURCE_GROUP="agriwizard-rg"
LOCATION="eastus"

az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
```

### 2. Create Azure Container Registry (ACR)
```bash
ACR_NAME="agriwizardacr"

az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic \
  --admin-enabled true
```

### 3. Create Log Analytics Workspace
```bash
LOG_ANALYTICS_WORKSPACE="agriwizard-law"

az monitor log-analytics workspace create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $LOG_ANALYTICS_WORKSPACE
```

### 4. Create Container Apps Environment
```bash
CONTAINER_APPS_ENV="agriwizard-env"

az containerapp env create \
  --name $CONTAINER_APPS_ENV \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --logs-workspace-id $(az monitor log-analytics workspace show \
    --resource-group $RESOURCE_GROUP \
    --workspace-name $LOG_ANALYTICS_WORKSPACE \
    --query customerId -o tsv) \
  --logs-workspace-key $(az monitor log-analytics workspace get-shared-keys \
    --resource-group $RESOURCE_GROUP \
    --workspace-name $LOG_ANALYTICS_WORKSPACE \
    --query primarySharedKey -o tsv)
```

### 5. Create Azure Database for PostgreSQL
```bash
POSTGRES_SERVER="agriwizard-db"
POSTGRES_ADMIN="agriwizard_admin"
POSTGRES_PASSWORD="<generate-secure-password>"

az postgres flexible-server create \
  --resource-group $RESOURCE_GROUP \
  --name $POSTGRES_SERVER \
  --admin-user $POSTGRES_ADMIN \
  --admin-password $POSTGRES_PASSWORD \
  --sku-name Standard_B1ms \
  --version 16 \
  --location $LOCATION \
  --public-access 0.0.0.0
```

### 6. Create Database and Schema
```bash
# Connect to PostgreSQL
az postgres flexible-server connect \
  --name $POSTGRES_SERVER \
  --admin-user $POSTGRES_ADMIN \
  --admin-password $POSTGRES_PASSWORD \
  --database postgres
```

```sql
-- Create database
CREATE DATABASE agriwizard;

-- Create user
CREATE USER agriwizard WITH PASSWORD '<same-password-as-above>';
GRANT ALL PRIVILEGES ON DATABASE agriwizard TO agriwizard;
```

---

## 🚀 Deploy Microservices

### 1. Set Environment Variables
```bash
# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer -o tsv)

# Get PostgreSQL connection string
POSTGRES_HOST="${POSTGRES_SERVER}.postgres.database.azure.com"
POSTGRES_DB="agriwizard"
POSTGRES_USER="agriwizard"
POSTGRES_PASSWORD="<your-password>"

# JWT Secret (generate a secure random string)
JWT_SECRET=$(openssl rand -base64 32)
```

### 2. Deploy IAM Service
```bash
az containerapp create \
  --name iam-service \
  --resource-group $RESOURCE_GROUP \
  --environment $CONTAINER_APPS_ENV \
  --image ${ACR_LOGIN_SERVER}/agriwizard-iam-service:latest \
  --target-port 8081 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 0.5 \
  --memory 1.0 \
  --env-vars \
    PORT=8081 \
    DB_HOST=$POSTGRES_HOST \
    DB_PORT=5432 \
    DB_USER=$POSTGRES_USER \
    DB_PASSWORD=$POSTGRES_PASSWORD \
    DB_NAME=$POSTGRES_DB \
    DB_SSLMODE=require \
    JWT_SECRET="$JWT_SECRET" \
    JWT_TTL_HOURS=24 \
    GIN_MODE=release
```

### 3. Deploy Hardware Service
```bash
az containerapp create \
  --name hardware-service \
  --resource-group $RESOURCE_GROUP \
  --environment $CONTAINER_APPS_ENV \
  --image ${ACR_LOGIN_SERVER}/agriwizard-hardware-service:latest \
  --target-port 8082 \
  --ingress internal \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 0.5 \
  --memory 1.0 \
  --env-vars \
    PORT=8082 \
    DB_HOST=$POSTGRES_HOST \
    DB_PORT=5432 \
    DB_USER=$POSTGRES_USER \
    DB_PASSWORD=$POSTGRES_PASSWORD \
    DB_NAME=$POSTGRES_DB \
    DB_SSLMODE=require \
    JWT_SECRET="$JWT_SECRET" \
    MQTT_BROKER="ssl://<your-hivemq-broker>:8883" \
    MQTT_USERNAME="<mqtt-username>" \
    MQTT_PASSWORD="<mqtt-password>" \
    ANALYTICS_SERVICE_URL="http://analytics-service.internal.azurecontainerapps.io:8083" \
    GIN_MODE=release
```

### 4. Deploy Analytics Service
```bash
az containerapp create \
  --name analytics-service \
  --resource-group $RESOURCE_GROUP \
  --environment $CONTAINER_APPS_ENV \
  --image ${ACR_LOGIN_SERVER}/agriwizard-analytics-service:latest \
  --target-port 8083 \
  --ingress internal \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 0.5 \
  --memory 1.0 \
  --env-vars \
    PORT=8083 \
    DB_HOST=$POSTGRES_HOST \
    DB_PORT=5432 \
    DB_USER=$POSTGRES_USER \
    DB_PASSWORD=$POSTGRES_PASSWORD \
    DB_NAME=$POSTGRES_DB \
    DB_SSLMODE=require \
    JWT_SECRET="$JWT_SECRET" \
    HARDWARE_SERVICE_URL="http://hardware-service.internal.azurecontainerapps.io:8082" \
    WEATHER_SERVICE_URL="http://weather-service.internal.azurecontainerapps.io:8084" \
    GIN_MODE=release
```

### 5. Deploy Weather Service
```bash
az containerapp create \
  --name weather-service \
  --resource-group $RESOURCE_GROUP \
  --environment $CONTAINER_APPS_ENV \
  --image ${ACR_LOGIN_SERVER}/agriwizard-weather-service:latest \
  --target-port 8084 \
  --ingress internal \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 0.5 \
  --memory 1.0 \
  --env-vars \
    PORT=8084 \
    JWT_SECRET="$JWT_SECRET" \
    USE_MOCK=true \
    OWM_API_KEY="" \
    OWM_BASE_URL="https://api.openweathermap.org/data/2.5" \
    LOCATION_LAT="6.9271" \
    LOCATION_LON="79.8612" \
    LOCATION_CITY="Colombo" \
    GIN_MODE=release
```

### 6. Deploy Notification Service
```bash
az containerapp create \
  --name notification-service \
  --resource-group $RESOURCE_GROUP \
  --environment $CONTAINER_APPS_ENV \
  --image ${ACR_LOGIN_SERVER}/agriwizard-notification-service:latest \
  --target-port 8085 \
  --ingress internal \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 0.5 \
  --memory 1.0 \
  --env-vars \
    PORT=8085 \
    DB_HOST=$POSTGRES_HOST \
    DB_PORT=5432 \
    DB_USER=$POSTGRES_USER \
    DB_PASSWORD=$POSTGRES_PASSWORD \
    DB_NAME=$POSTGRES_DB \
    DB_SSLMODE=require \
    NATS_URL="nats://<nats-server>:4222" \
    SMTP_HOST="<smtp-server>" \
    SMTP_PORT=587 \
    SMTP_USERNAME="<smtp-user>" \
    SMTP_PASSWORD="<smtp-password>"
```

---

## 🌐 Setup API Gateway (Traefik)

### Option 1: Azure Container Apps Ingress
```bash
# Get IAM service URL
IAM_URL=$(az containerapp show \
  --name iam-service \
  --resource-group $RESOURCE_GROUP \
  --query properties.configuration.ingress.fqdn \
  -o tsv)

echo "IAM Service URL: https://$IAM_URL"
```

### Option 2: Deploy Traefik as Container App
```bash
az containerapp create \
  --name api-gateway \
  --resource-group $RESOURCE_GROUP \
  --environment $CONTAINER_APPS_ENV \
  --image traefik:v3.0 \
  --target-port 8080 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 2 \
  --cpu 0.5 \
  --memory 1.0
```

---

## 🔐 Store Secrets in Azure Key Vault (Recommended)

### 1. Create Key Vault
```bash
KEY_VAULT_NAME="agriwizard-kv"

az keyvault create \
  --name $KEY_VAULT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION
```

### 2. Store Secrets
```bash
az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "postgres-password" \
  --value "$POSTGRES_PASSWORD"

az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "jwt-secret" \
  --value "$JWT_SECRET"

az keyvault secret set \
  --vault-name $KEY_VAULT_NAME \
  --name "mqtt-password" \
  --value "<mqtt-password>"
```

### 3. Reference Secrets in Container Apps
```bash
az containerapp update \
  --name iam-service \
  --resource-group $RESOURCE_GROUP \
  --secrets "postgres-password=<keyvault-secret-reference>"
```

---

## ✅ Verify Deployment

### 1. List All Container Apps
```bash
az containerapp list \
  --resource-group $RESOURCE_GROUP \
  --query "[].{name:name, url:properties.configuration.ingress.fqdn, active:properties.activeScale}" \
  -o table
```

### 2. Test Health Endpoints
```bash
# Get service URLs
IAM_URL=$(az containerapp show --name iam-service --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn -o tsv)

# Test health
curl https://$IAM_URL/health

# Expected output:
# {"status":"ok","service":"iam-service","db_ready":true,"migrated":true}
```

### 3. View Logs
```bash
az containerapp logs show \
  --name iam-service \
  --resource-group $RESOURCE_GROUP \
  --follow
```

---

## 🔄 CI/CD Integration

### Update GitHub Secrets (Publish Profile Auth)
```bash
# Add these to GitHub → Settings → Secrets and variables → Actions
AZURE_CONTAINERAPP_PUBLISH_PROFILE=<publish-profile-xml>
ACR_USERNAME=<acr-admin-username>
ACR_PASSWORD=<acr-admin-password>
```

**How to get publish profile:**
1. Go to Azure Portal → Container App
2. Go to **Deploy** → **Publishing profile**
3. Copy the XML content

---

## 💰 Cost Optimization

### 1. Scale to Zero (for dev environments)
```bash
az containerapp update \
  --name iam-service \
  --resource-group $RESOURCE_GROUP \
  --min-replicas 0 \
  --max-replicas 2
```

### 2. Use Spot Instances
```bash
az containerapp update \
  --name iam-service \
  --resource-group $RESOURCE_GROUP \
  --spot-price 0.05
```

---

## 🛠️ Troubleshooting

### 1. Check Container App Status
```bash
az containerapp show \
  --name iam-service \
  --resource-group $RESOURCE_GROUP \
  --query "{status:properties.provisioningState, activeReplicas:properties.activeScale}"
```

### 2. View All Revisions
```bash
az containerapp revision list \
  --name iam-service \
  --resource-group $RESOURCE_GROUP \
  --query "[].{name:name, active:properties.active, createdTime:properties.createdTime}" \
  -o table
```

### 3. Check Environment Health
```bash
az containerapp env show \
  --name $CONTAINER_APPS_ENV \
  --resource-group $RESOURCE_GROUP \
  --query "{status:properties.status, vnet:properties.vnetConfiguration.name}"
```

---

## 📊 Monitoring Setup

### 1. Enable Application Insights
```bash
APP_INSIGHTS_NAME="agriwizard-ai"

az monitor app-insights component create \
  --app $APP_INSIGHTS_NAME \
  --location $LOCATION \
  --resource-group $RESOURCE_GROUP \
  --workspace $(az monitor log-analytics workspace show \
    --resource-group $RESOURCE_GROUP \
    --workspace-name $LOG_ANALYTICS_WORKSPACE \
    --query id -o tsv)
```

### 2. Configure Container App to Send Logs
```bash
az containerapp update \
  --name iam-service \
  --resource-group $RESOURCE_GROUP \
  --registry-server $ACR_LOGIN_SERVER \
  --transport http
```

---

## 📝 Next Steps

1. **Set up Custom Domain**: Configure DNS and SSL certificates
2. **Enable Dapr**: For service-to-service communication
3. **Configure Autoscaling**: Based on CPU/memory/HTTP metrics
4. **Set up Alerts**: For errors and performance issues
5. **Implement Blue-Green Deployments**: Using Container Apps revisions

---

## 🐇 RabbitMQ Integration

RabbitMQ is used for inter-service messaging (replacing Azure Service Bus).

### Architecture

```
Hardware Service ──publish──▶ RabbitMQ ──consume──▶ Analytics Service
                              │
                              └──consume──▶ Notification Service
```

### Deploy RabbitMQ to Azure Container Apps

```bash
# Create RabbitMQ container app
az containerapp create \
  --name agriwizard-rabbitmq \
  --resource-group $RESOURCE_GROUP \
  --environment $CONTAINER_APPS_ENV \
  --image rabbitmq:3.12-management \
  --port 5672 \
  --ingress external \
  --cpu 0.5 --memory 1Gi \
  --min-replicas 1 --max-replicas 1
```

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `RABBITMQ_URL` | RabbitMQ connection | `amqp://guest:guest@rabbitmq:5672` |
| `RABBITMQ_QUEUE` | Queue name | `telemetry` |

### Create Queue (First Time)

```bash
# Connect to RabbitMQ management UI and create queue
# Or use management API
curl -u guest:guest -X PUT http://$RABBITMQ_HOST:15672/api/definitions/%2f \
  -H "content-type:application/json" \
  -d '{"queues":[{"name":"telemetry","durable":true}]}'
```

---

## 📚 References

- [Azure Container Apps Documentation](https://docs.microsoft.com/azure/container-apps/)
- [Deploy to Container Apps from GitHub Actions](https://docs.microsoft.com/azure/container-apps/github-actions)
- [Container Apps Environment](https://docs.microsoft.com/azure/container-apps/environment)
- [Container Apps Ingress](https://docs.microsoft.com/azure/container-apps/ingress)
- [RabbitMQ Documentation](https://www.rabbitmq.com/)
