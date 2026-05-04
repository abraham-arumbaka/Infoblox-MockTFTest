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
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Vault Provider  –  reads Azure SP credentials from HashiCorp Vault
# Running locally:  docker run --cap-add=IPC_LOCK -e 'VAULT_DEV_ROOT_TOKEN_ID=root'
#                              -p 8200:8200 hashicorp/vault:2.0
# ---------------------------------------------------------------------------
provider "vault" {
  address = var.vault_address
  token   = var.vault_token
}

# ---------------------------------------------------------------------------
# Azure Provider  –  credentials sourced from Vault (see vault.tf)
# ---------------------------------------------------------------------------
provider "azurerm" {
  features {}

  subscription_id = data.vault_generic_secret.azure_sp.data["subscription_id"]
  tenant_id       = data.vault_generic_secret.azure_sp.data["tenant_id"]
  client_id       = data.vault_generic_secret.azure_sp.data["client_id"]
  client_secret   = data.vault_generic_secret.azure_sp.data["client_secret"]

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
