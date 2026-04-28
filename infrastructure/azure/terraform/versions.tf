terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Configure Azure Provider
provider "azurerm" {
  features {
    key_vault {
      purge_soft_deleted_secrets_on_destroy = true
    }
    log_analytics_workspace {
      permanent_delete_on_destroy = true
    }
  }
  use_cli = true
  use_msi = false
  skip_provider_registration = false
}

# Random password generator for PostgreSQL
resource "random_password" "postgres_password" {
  length  = 32
  special = true
  override_special = "!#$%&*()-_=+[]{}|?"
}

# Random password for Key Vault
resource "random_password" "keyvault_password" {
  length  = 32
  special = true
}

# Random string for resource uniqueness
resource "random_string" "app_suffix" {
  length  = 6
  upper   = false
  lower   = true
  numeric = true
}