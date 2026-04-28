output "resource_group_name" {
  description = "Name of the Azure Resource Group"
  value       = azurerm_resource_group.main.name
}

output "vnet_name" {
  description = "Name of the provisioned Virtual Network"
  value       = azurerm_virtual_network.main.name
}

output "vnet_id" {
  description = "Resource ID of the Virtual Network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_cidr" {
  description = "CIDR block allocated from Infoblox and assigned to the VNET"
  value       = infoblox_ipv4_network.vnet.cidr
}

output "infoblox_network_ref" {
  description = "Infoblox internal object reference (_ref) for the allocated network"
  value       = infoblox_ipv4_network.vnet.id
}

output "subnet_cidrs" {
  description = "Map of subnet name → allocated CIDR"
  value = {
    for name, subnet in azurerm_subnet.subnets :
    name => subnet.address_prefixes[0]
  }
}
