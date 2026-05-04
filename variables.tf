# ---------------------------------------------------------------------------
# Vault
# ---------------------------------------------------------------------------
variable "vault_address" {
  description = "HashiCorp Vault server address (e.g. http://localhost:8200)"
  type        = string
  default     = "http://localhost:8200"
}

variable "vault_token" {
  description = "Vault token used to authenticate. Use VAULT_TOKEN env var in CI/production."
  type        = string
  sensitive   = true
  default     = "root"   # default matches Vault dev-mode root token
}

variable "vault_kv_mount" {
  description = "Vault KV v2 mount point (the secrets engine mount, e.g. 'secret')"
  type        = string
  default     = "secret"
}

variable "vault_secret_path" {
  description = "KV v2 secret name within the mount (e.g. 'azure/sp' for secret/data/azure/sp)"
  type        = string
  default     = "azure/sp"
}

# ---------------------------------------------------------------------------
# Azure
# ---------------------------------------------------------------------------
# NOTE: subscription_id and tenant_id are now sourced from Vault (vault.tf).
# These variables are kept for backwards compatibility but are no longer
# passed to the azurerm provider — Vault is the single source of truth.
variable "azure_subscription_id" {
  description = "(Unused — sourced from Vault) Azure Subscription ID"
  type        = string
  default     = ""
}

variable "azure_tenant_id" {
  description = "(Unused — sourced from Vault) Azure Tenant / Directory ID"
  type        = string
  default     = ""
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Deployment environment tag (dev / staging / prod)"
  type        = string
  default     = "dev"
}

variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "rg-temp-vnet"
}

variable "vnet_name" {
  description = "Name for the Azure Virtual Network"
  type        = string
  default     = "vnet-temp"
}

variable "subnet_names" {
  description = "List of subnet names to carve out of the allocated VNET CIDR"
  type        = list(string)
  default     = ["snet-app", "snet-data", "snet-mgmt"]
}

variable "subnet_prefix_length" {
  description = "Prefix length for each subnet (carved from the VNET CIDR)"
  type        = number
  default     = 27
}

# ---------------------------------------------------------------------------
# Infoblox
# ---------------------------------------------------------------------------
variable "infoblox_server" {
  description = "Hostname or IP of the Infoblox NIOS / mock server"
  type        = string
  default     = "localhost"
}

variable "infoblox_port" {
  description = "HTTPS port for Infoblox WAPI"
  type        = string
  default     = "8443"
}

variable "infoblox_username" {
  description = "Infoblox admin username"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "infoblox_password" {
  description = "Infoblox admin password"
  type        = string
  default     = "infoblox"
  sensitive   = true
}

variable "infoblox_wapi_version" {
  description = "WAPI version exposed by the Infoblox server"
  type        = string
  default     = "2.5"
}

variable "infoblox_sslmode" {
  description = "Maps to SslVerify in the go-client: false = skip TLS verification (use for self-signed/mock), true = enforce certificate verification"
  type        = bool
  default     = false
}

variable "infoblox_network_container" {
  description = "Parent CIDR container in Infoblox to allocate from"
  type        = string
  default     = "10.0.0.0/8"
}

variable "infoblox_network_view" {
  description = "Infoblox network view to use"
  type        = string
  default     = "default"
}

variable "vnet_prefix_length" {
  description = "Prefix length for the VNET block requested from Infoblox (e.g. 24 = /24)"
  type        = number
  default     = 24
}
