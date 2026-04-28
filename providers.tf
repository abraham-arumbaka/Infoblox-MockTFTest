terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
    infoblox = {
      source  = "infobloxopen/infoblox"
      version = "~> 2.5"
    }
  }
}

# ---------------------------------------------------------------------------
# Azure Provider
# ---------------------------------------------------------------------------
provider "azurerm" {
  features {}

  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id

  # Disable automatic resource provider registration (azurerm v3 equivalent).
  # Microsoft.Network is pre-registered on all subscriptions by default.
  skip_provider_registration = true
}

# ---------------------------------------------------------------------------
# Infoblox Provider  –  points at the local mock server (mock/mock_infoblox.py)
# For production: replace server / credentials via env vars or a tfvars file
#   export INFOBLOX_SERVER=<real-nios-host>
#   export INFOBLOX_USERNAME=<user>
#   export INFOBLOX_PASSWORD=<pass>
# ---------------------------------------------------------------------------
provider "infoblox" {
  server       = var.infoblox_server
  port         = var.infoblox_port
  username     = var.infoblox_username
  password     = var.infoblox_password
  wapi_version = var.infoblox_wapi_version
  sslmode      = var.infoblox_sslmode
}
