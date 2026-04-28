# ---------------------------------------------------------------------------
# 1. Resource Group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ---------------------------------------------------------------------------
# 2. Infoblox – request next available CIDR block from the parent container
#
#    infoblox_ipv4_network with `allocate_prefix = true` and `parent_cidr`
#    triggers the WAPI  networkcontainer?_function=next_available_network  call
#    and creates a network object in IPAM.
#    The allocated CIDR is then available as: infoblox_ipv4_network.vnet.cidr
# ---------------------------------------------------------------------------
resource "infoblox_ipv4_network" "vnet" {
  parent_cidr        = var.infoblox_network_container
  allocate_prefix_len = var.vnet_prefix_length
  network_view       = var.infoblox_network_view
  comment       = "VNET CIDR for ${var.vnet_name} [${var.environment}]"

  # Optional IPAM extensible attributes — harmless if not supported by mock
  ext_attrs = jsonencode({
    "Tenant ID"   = var.environment
    "Network Name" = var.vnet_name
  })
}

# ---------------------------------------------------------------------------
# 3. Azure Virtual Network  –  address space comes from Infoblox allocation
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # The CIDR block Infoblox just allocated
  address_space = [infoblox_ipv4_network.vnet.cidr]

  tags = {
    environment    = var.environment
    managed_by     = "terraform"
    ipam_ref       = infoblox_ipv4_network.vnet.id
  }
}

# ---------------------------------------------------------------------------
# 4. Subnets  –  carve equal-size blocks out of the Infoblox-allocated VNET CIDR
#
#    cidrsubnet("10.1.0.0/24", 3, index)  →  /27 subnets:
#      index 0 → 10.1.0.0/27
#      index 1 → 10.1.0.32/27
#      index 2 → 10.1.0.64/27
# ---------------------------------------------------------------------------
locals {
  # New bits = subnet prefix length - VNET prefix length
  subnet_newbits = var.subnet_prefix_length - var.vnet_prefix_length
}

resource "azurerm_subnet" "subnets" {
  for_each = { for idx, name in var.subnet_names : name => idx }

  name                 = each.key
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name

  address_prefixes = [
    cidrsubnet(infoblox_ipv4_network.vnet.cidr, local.subnet_newbits, each.value)
  ]
}
