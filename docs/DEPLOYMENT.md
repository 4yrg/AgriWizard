# AgriWizard Azure Deployment Guide

## Prerequisites

1. **Azure CLI** installed and authenticated
   ```bash
   az login
   az account set --subscription <your-subscription-id>
   ```

2. **Terraform** installed (v1.0+)

3. **Docker Desktop** running

4. **Go** installed (for service compilation)

## Quick Deploy

```bash
cd terraform

# Generate secrets
node -e "
const crypto = require('crypto');
const dbPassword = crypto.randomBytes(16).toString('base64').replace(/[^a-zA-Z0-9]/g, '').slice(0,24);
const jwtSecret = crypto.randomBytes(32).toString('base64').replace(/[^a-zA-Z0-9]/g, '').slice(0,48);
require('fs').writeFileSync('.env', 'POSTGRES_PASSWORD=' + dbPassword + '\nJWT_SECRET=' + jwtSecret + '\n');
console.log('Secrets generated in .env');
"

# Load secrets
export $(cat .env | grep -v '^#' | xargs)
export TF_VAR_postgresql_admin_password="$POSTGRES_PASSWORD"
export TF_VAR_jwt_secret="$JWT_SECRET"

# Initialize and deploy
terraform init
terraform plan -var-file="environments/prod.tfvars"
terraform apply -var-file="environments/prod.tfvars" -auto-approve
```

## Deploy Services (After Infrastructure)

```bash
# Login to ACR
az acr login --name agriwizardacrprod

# Build and push each service
cd ~/Projects/AgriWizard

docker build -t agriwizardacrprod.azurecr.io/agriwizard-iam-service:latest -f services/iam-service/Dockerfile .
docker push agriwizardacrprod.azurecr.io/agriwizard-iam-service:latest

docker build -t agriwizardacrprod.azurecr.io/agriwizard-hardware-service:latest -f services/hardware-service/Dockerfile .
docker push agriwizardacrprod.azurecr.io/agriwizard-hardware-service:latest

docker build -t agriwizardacrprod.azurecr.io/agriwizard-analytics-service:latest -f services/analytics-service/Dockerfile .
docker push agriwizardacrprod.azurecr.io/agriwizard-analytics-service:latest

docker build -t agriwizardacrprod.azurecr.io/agriwizard-weather-service:latest -f services/weather-service/Dockerfile .
docker push agriwizardacrprod.azurecr.io/agriwizard-weather-service:latest

docker build -t agriwizardacrprod.azurecr.io/agriwizard-notification-service:latest -f services/notification-service/Dockerfile .
docker push agriwizardacrprod.azurecr.io/agriwizard-notification-service:latest

# Apply terraform again to update container apps with new images
terraform apply -var-file="environments/prod.tfvars" -auto-approve
```

## Post-Deployment Configuration

### 1. Disable PostgreSQL SSL Requirement
```bash
az postgres flexible-server parameter set \
  --server-name agriwizard-db-prod \
  --resource-group agriwizard-rg \
  --name require_secure_transport \
  --value off
```

### 2. Add PostgreSQL Firewall Rule for Container Apps
```bash
# Get Container App outbound IP
OUTBOUND_IP=$(az containerapp show --name prod-iam-service --resource-group agriwizard-rg --query "properties.outboundIpAddresses[0]" -o tsv)

# Add firewall rule
az postgres flexible-server firewall-rule create \
  --name agriwizard-db-prod \
  --resource-group agriwizard-rg \
  --rule-name AllowContainerApps \
  --start-ip-address $OUTBOUND_IP \
  --end-ip-address $OUTBOUND_IP
```

### 3. Import API into APIM
```bash
# Delete existing API if present
az apim api delete --resource-group agriwizard-rg --service-name agriwizard-apim-prod --api-id agriwizard-api --yes 2>/dev/null

# Import OpenAPI spec
az apim api import \
  --resource-group agriwizard-rg \
  --service-name agriwizard-apim-prod \
  --path "" \
  --specification-format OpenApi \
  --specification-path "../docs/swagger-apim.json" \
  --api-id agriwizard-api \
  --display-name "AgriWizard API" \
  --protocols https \
  --subscription-required false

# Set service URL to IAM service
az apim api update \
  --resource-group agriwizard-rg \
  --service-name agriwizard-apim-prod \
  --api-id agriwizard-api \
  --service-url "https://$(az containerapp show --name prod-iam-service --resource-group agriwizard-rg --query properties.latestRevisionFqdn -o tsv)"

# Apply routing policy
ACCESS_TOKEN=$(az account get-access-token --resource https://management.azure.com --query accessToken -o tsv)

curl -X PUT "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/resourceGroups/agriwizard-rg/providers/Microsoft.ApiManagement/service/agriwizard-apim-prod/apis/agriwizard-api/policies/policy?api-version=2023-09-01-preview" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d @- << 'EOF'
{
  "properties": {
    "format": "rawxml",
    "value": "<policies><inbound><base /><choose><when condition=\"@(context.Request.Url.Path.Contains(&quot;weather&quot;))\"><set-backend-service base-url=\"https://WEATHER_FQDN\" /></when><when condition=\"@(context.Request.Url.Path.Contains(&quot;hardware&quot;))\"><set-backend-service base-url=\"https://HARDWARE_FQDN\" /></when><when condition=\"@(context.Request.Url.Path.Contains(&quot;analytics&quot;))\"><set-backend-service base-url=\"https://ANALYTICS_FQDN\" /></when><when condition=\"@(context.Request.Url.Path.Contains(&quot;notification&quot;) || context.Request.Url.Path.Contains(&quot;template&quot;))\"><set-backend-service base-url=\"https://NOTIFICATION_FQDN\" /></when></choose></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>"
  }
}
EOF
```

## API Endpoints

**Base URL**: `https://agriwizard-apim-prod.azure-api.net`

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/iam/register` | POST | Register user |
| `/api/v1/iam/login` | POST | Login |
| `/api/v1/iam/profile` | GET | Get profile |
| `/api/v1/weather/current` | GET | Current weather |
| `/api/v1/weather/forecast` | GET | Weather forecast |
| `/api/v1/hardware/equipments` | GET | List equipment |
| `/api/v1/hardware/sensors` | GET | List sensors |
| `/api/v1/analytics/decisions/summary` | GET | Decision summary |
| `/api/v1/notifications` | GET | List notifications |
| `/api/v1/templates` | GET | List templates |

## Quick Test

```bash
# Register
curl -X POST https://agriwizard-apim-prod.azure-api.net/api/v1/iam/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"Test123456!","full_name":"Test User"}'

# Login
TOKEN=$(curl -s -X POST https://agriwizard-apim-prod.azure-api.net/api/v1/iam/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"Test123456!"}' | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

# Test any endpoint
curl https://agriwizard-apim-prod.azure-api.net/api/v1/weather/current \
  -H "Authorization: Bearer $TOKEN"
```

## Destroy Resources

```bash
# Via Terraform
cd terraform
export $(cat .env | grep -v '^#' | xargs)
export TF_VAR_postgresql_admin_password="$POSTGRES_PASSWORD"
export TF_VAR_jwt_secret="$JWT_SECRET"
terraform destroy -var-file="environments/prod.tfvars" -auto-approve

# Or delete resource group directly (faster)
az group delete --name agriwizard-rg --yes
```

## Files Structure

```
terraform/
├── main.tf                    # Main infrastructure
├── variables.tf               # Variable definitions
├── provider.tf                # Azure provider config
├── container-apps-module.tf   # Container apps integration
├── environments/
│   └── prod.tfvars           # Production variables
└── modules/
    └── container-apps/
        ├── main.tf           # Container app resources
        └── variables.tf      # Module variables

docs/
├── swagger.yaml              # OpenAPI 3.0 spec
├── swagger.json              # JSON version
├── swagger-apim.json         # APIM-specific version
└── apim-policy.xml           # APIM routing policy
```

## Secrets Management

Secrets are stored in `.env` file (gitignored):
- `POSTGRES_PASSWORD` - Database password
- `JWT_SECRET` - JWT signing key

These are passed to Terraform via environment variables and stored in Azure Key Vault during deployment.
