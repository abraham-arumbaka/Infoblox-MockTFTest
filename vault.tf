# ---------------------------------------------------------------------------
# Vault Data Source — Azure Service Principal credentials
#
# Expects a KV secret at var.vault_secret_path with these keys:
#   subscription_id  — Azure Subscription ID
#   tenant_id        — Azure Tenant / Directory ID
#   client_id        — Service Principal Application (client) ID
#   client_secret    — Service Principal client secret
#
# To seed the secret in Vault dev mode:
#   vault kv put secret/azure/sp \
#     subscription_id="<sub-id>" \
#     tenant_id="<tenant-id>"    \
#     client_id="<app-id>"       \
#     client_secret="<secret>"
# ---------------------------------------------------------------------------
data "vault_generic_secret" "azure_sp" {
  path = var.vault_secret_path
}
