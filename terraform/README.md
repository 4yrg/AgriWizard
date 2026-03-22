# AgriWizard - Azure Terraform Deployment

Production-ready Terraform infrastructure for AgriWizard Smart Greenhouse Management System.

## 📁 Project Structure

```
terraform/
├── main.tf                  # Main configuration and provider setup
├── variables.tf             # Input variables
├── outputs.tf              # Output values
├── providers.tf            # Provider configurations
├── backend.tf              # Terraform backend configuration
├── modules/
│   ├── container-apps/     # Container Apps modules
│   ├── networking/         # Network resources
│   └── database/           # Database resources
├── environments/
│   ├── dev.tfvars          # Development environment variables
│   ├── staging.tfvars      # Staging environment variables
│   └── prod.tfvars         # Production environment variables
└── scripts/
    └── init.sh             # Initialization script
```

## 🚀 Quick Start

```bash
# Navigate to terraform directory
cd terraform

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment (development)
terraform plan -var-file=environments/dev.tfvars

# Apply deployment
terraform apply -var-file=environments/dev.tfvars
```

## 🔐 Prerequisites

1. **Azure CLI** installed and authenticated
   ```bash
   az login
   az account set --subscription "<your-subscription-id>"
   ```

2. **Terraform** v1.5.0 or later
   ```bash
   terraform --version
   ```

3. **Azure Container Registry** with pushed images
   ```bash
   # Build and push images using GitHub Actions
   # Images should be available at: <acr-name>.azurecr.io/agriwizard-{service}:<tag>
   ```

## 📋 Configuration

### Environment Variables

Create `environments/dev.tfvars`:

```hcl
resource_group_name     = "agriwizard-rg-dev"
location                = "eastus"
environment             = "dev"
acr_name                = "agriwizardacrdev"
container_apps_env_name = "agriwizard-env-dev"
postgresql_server_name  = "agriwizard-db-dev"
iot_hub_name            = "agriwizard-iot-dev"
key_vault_name          = "agriwizard-kv-dev"
apim_name               = "agriwizard-apim-dev"

# Container Apps Configuration
cpu_core           = 0.5
memory_size        = 1.0
min_replicas       = 1
max_replicas       = 3

# Database Configuration
postgresql_admin_username = "agriadmin"
postgresql_sku_name       = "Standard_B1ms"
postgresql_version        = "16"

# Image Configuration
image_tag = "latest"
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure API Management                      │
│                    (External Ingress)                        │
│              https://agriwizard.apim.azure.net              │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┼────────────┬────────────┐
        │            │            │            │
        ▼            ▼            ▼            ▼
   ┌────────┐  ┌──────────┐  ┌───────────┐  ┌──────────┐
   │   IAM  │  │ Hardware │  │ Analytics │  │ Weather  │
   │ :8081  │  │  :8082   │  │   :8083   │  │  :8084   │
   └────────┘  └──────────┘  └───────────┘  └──────────┘
        │            │            │            │
        └────────────┴────────────┴────────────┘
                         │
                         ▼
              ┌─────────────────────┐
              │  Azure PostgreSQL   │
              │  (Flexible Server)  │
              └─────────────────────┘
                         │
              ┌─────────────────────┐
              │    Azure IoT Hub    │
              └─────────────────────┘
```

## 🔧 Modules

### Container Apps Module

Deploys all 4 microservices with:
- Internal ingress for inter-service communication
- Environment variables from Key Vault
- Autoscaling configuration
- Log Analytics integration

### Database Module

Provisions Azure Database for PostgreSQL:
- Flexible Server deployment
- Private endpoint support
- Automated backups
- Geo-redundant storage

### Networking Module

Creates network infrastructure:
- Virtual Network
- Subnets for Container Apps
- Private DNS zones
- Network security groups

## 📊 Monitoring

All resources are integrated with:
- **Log Analytics Workspace**: Centralized logging
- **Application Insights**: Application performance monitoring
- **Azure Monitor**: Infrastructure metrics and alerts

## 🔐 Security

- **Managed Identity**: All services use system-assigned managed identity
- **Key Vault Integration**: Secrets stored securely, no hardcoded values
- **Private Networking**: Resources communicate over private endpoints
- **HTTPS Only**: All ingress enforced with TLS

## 💰 Cost Optimization

- **Dev Environment**: Scale to zero enabled, basic SKUs
- **Staging Environment**: Balanced performance and cost
- **Production Environment**: High availability, premium SKUs

## 🧹 Cleanup

```bash
# Destroy all resources
terraform destroy -var-file=environments/dev.tfvars

# Remove state file (optional)
rm -rf .terraform/
rm terraform.tfstate
rm terraform.tfstate.backup
```

## 📚 References

- [Azure Container Apps Documentation](https://docs.microsoft.com/azure/container-apps/)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure API Management](https://docs.microsoft.com/azure/api-management/)
- [Azure Database for PostgreSQL](https://docs.microsoft.com/azure/postgresql/)

## ⚠️ Important Notes

1. **Image Availability**: Ensure Docker images are pushed to ACR before running `terraform apply`
2. **Secret Management**: Create secrets in Key Vault or use Azure CLI to set them post-deployment
3. **DNS Configuration**: Custom domain setup requires additional DNS configuration
4. **Region Availability**: Verify all services are available in your selected region
5. **Quota Limits**: Check subscription quotas for Container Apps and PostgreSQL

## 🆘 Troubleshooting

### Common Issues

1. **ACR Authentication Failed**
   ```bash
   az acr login --name <acr-name>
   ```

2. **Container App Not Starting**
   ```bash
   az containerapp logs show \
     --name iam-service \
     --resource-group <rg-name> \
     --follow
   ```

3. **Database Connection Failed**
   - Verify firewall rules allow Container Apps subnet
   - Check connection string in Key Vault
   - Ensure PostgreSQL admin credentials are correct

## 📞 Support

For issues or questions:
- Review Terraform logs: `TF_LOG=DEBUG terraform apply`
- Check Azure Activity Log in the portal
- Consult Azure documentation for specific services
