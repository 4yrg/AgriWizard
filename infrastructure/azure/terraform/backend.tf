
terraform {
  backend "azurerm" {
    resource_group_name  = "agriwizard-tf-rg"
    storage_account_name = "tfstate0130"
    container_name       = "tfstate"
    key                  = "agriwizard/dev/terraform.tfstate"
    use_azuread_auth    = true
  }
}
