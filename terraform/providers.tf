# =============================================================================
# providers.tf — Provider configuration for Azure Sentinel SecOps Lab
# =============================================================================
# Configures the AzureRM and AzAPI providers required for deploying all
# resources in this lab.  The backend block is commented out; uncomment and
# configure it when you're ready to use remote state in Azure Storage.
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }

    azapi = {
      source  = "azure/azapi"
      version = "~> 1.9"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # ---------------------------------------------------------------------------
  # Remote State Backend (Azure Storage)
  # ---------------------------------------------------------------------------
  # Uncomment the block below to store Terraform state in Azure Blob Storage.
  # Before enabling, create the storage account and container:
  #
  #   az group create -n tfstate-rg -l eastus
  #   az storage account create -n <unique_name> -g tfstate-rg -l eastus --sku Standard_LRS
  #   az storage container create -n tfstate --account-name <unique_name>
  #
  # Then fill in the values below.
  # ---------------------------------------------------------------------------
  # backend "azurerm" {
  #   resource_group_name  = "tfstate-rg"
  #   storage_account_name = "<your_storage_account_name>"
  #   container_name       = "tfstate"
  #   key                  = "sentinel-secops.tfstate"
  # }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }

    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
  }
}

provider "azapi" {}
