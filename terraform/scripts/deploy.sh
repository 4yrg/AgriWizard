#!/bin/bash
# =============================================================================
# AgriWizard - Terraform Deployment Script
# =============================================================================
# This script automates the deployment of AgriWizard to Azure.
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}\n"
}

print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform v1.5.0 or later."
        exit 1
    fi
    echo "✓ Terraform version: $(terraform version -json | jq -r '.terraform_version' 2>/dev/null || terraform version | head -1)"

    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install Azure CLI."
        exit 1
    fi
    echo "✓ Azure CLI version: $(az version --query azureCliVersion -o tsv)"

    # Check Azure login
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Please run 'az login'."
        exit 1
    fi
    echo "✓ Azure CLI logged in as: $(az account show --query user.name -o tsv)"

    # Check jq (optional but helpful)
    if command -v jq &> /dev/null; then
        echo "✓ jq is installed (optional dependency)"
    else
        print_warning "jq is not installed. Some output formatting may be limited."
    fi
}

# Initialize Terraform
init_terraform() {
    print_header "Initializing Terraform"

    # Get the terraform directory (parent of scripts/)
    TERRAFORM_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    cd "$TERRAFORM_DIR"

    echo "Working directory: $(pwd)"

    terraform init

    echo "✓ Terraform initialized"
}

# Validate Terraform configuration
validate_terraform() {
    print_header "Validating Terraform Configuration"

    terraform validate

    if [ $? -eq 0 ]; then
        echo "✓ Terraform configuration is valid"
    else
        print_error "Terraform validation failed"
        exit 1
    fi
}

# Plan deployment
plan_deployment() {
    local environment=$1

    print_header "Planning Deployment for $environment"

    terraform plan \
        -var-file="environments/${environment}.tfvars" \
        -out="tfplan-${environment}"

    echo "✓ Terraform plan created: tfplan-${environment}"
}

# Apply deployment
apply_deployment() {
    local environment=$1

    print_header "Applying Deployment for $environment"

    terraform apply \
        -var-file="environments/${environment}.tfvars" \
        "tfplan-${environment}"

    echo "✓ Deployment completed for $environment"
}

# Show outputs
show_outputs() {
    print_header "Deployment Outputs"

    terraform output -json | jq -r '
        to_entries[] |
        "\(.key): \(.value.value)"
    ' 2>/dev/null || terraform output

    echo ""
    print_header "Next Steps"
    echo "1. Review the outputs above for service URLs and connection strings"
    echo "2. Configure your DNS and custom domains if needed"
    echo "3. Set up CI/CD pipeline to push new images to ACR"
    echo "4. Monitor the services in Azure Portal"
}

# Cleanup function
cleanup() {
    print_header "Cleanup"

    read -p "Are you sure you want to destroy all resources? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Cleanup cancelled"
        exit 0
    fi

    local environment=$1

    terraform destroy \
        -var-file="environments/${environment}.tfvars" \
        -auto-approve

    echo "✓ Cleanup completed"
}

# Main script
main() {
    local command=${1:-help}
    local environment=${2:-dev}

    case $command in
        init)
            check_prerequisites
            init_terraform
            ;;
        validate)
            validate_terraform
            ;;
        plan)
            check_prerequisites
            init_terraform
            validate_terraform
            plan_deployment $environment
            ;;
        apply)
            check_prerequisites
            init_terraform
            validate_terraform
            plan_deployment $environment
            apply_deployment $environment
            show_outputs
            ;;
        destroy)
            check_prerequisites
            init_terraform
            cleanup $environment
            ;;
        output)
            show_outputs
            ;;
        help|*)
            echo "AgriWizard Terraform Deployment Script"
            echo ""
            echo "Usage: $0 <command> [environment]"
            echo ""
            echo "Commands:"
            echo "  init      Initialize Terraform and download providers"
            echo "  validate  Validate Terraform configuration"
            echo "  plan      Create deployment plan"
            echo "  apply     Deploy infrastructure (runs init, validate, plan, apply)"
            echo "  destroy   Destroy all resources"
            echo "  output    Show deployment outputs"
            echo "  help      Show this help message"
            echo ""
            echo "Environments:"
            echo "  dev       Development environment (default)"
            echo "  staging   Staging environment"
            echo "  prod      Production environment"
            echo ""
            echo "Examples:"
            echo "  $0 init"
            echo "  $0 plan dev"
            echo "  $0 apply dev"
            echo "  $0 apply prod"
            echo "  $0 destroy dev"
            ;;
    esac
}

# Run main function
main "$@"
