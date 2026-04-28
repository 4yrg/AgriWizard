# AgriWizard - Terraform Configuration

## Folder Structure

```
infrastructure/azure/terraform/
├── main.tf                    # Main configuration
├── providers.tf              # Provider configuration
├── variables.tf              # Variables
├── outputs.tf                 # Outputs
├── resource-group.tf         # Resource group
├── vnet.tf                  # Virtual network
├── postgresql.tf             # Azure Database for PostgreSQL
├── keyvault.tf              # Key Vault
├── servicebus.tf             # Azure Service Bus
├── iothub.tf               # Azure IoT Hub
├── container-apps.tf        # Container Apps environment & apps
├── apim.tf                 # API Management
├── storage.tf              # Blob Storage
├── app-insights.tf         # Application Insights
├── acr.tf                 # Container Registry
└── versions.tf            # Required providers
```

## Quick Start

```bash
# 1. Authenticate to Azure
az login
az account set --subscription <subscription-id>

# 2. Create terraform backend storage (if needed)
terraform init -backend-config="storage_account_name=terraformstate" -backend-config="container_name=tfstate"

# 3. Plan and apply
terraform plan -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
```

## Environment Files

```
environments/
├── dev.tfvars     # Development
├── staging.tfvars # Staging
└── prod.tfvars   # Production
```