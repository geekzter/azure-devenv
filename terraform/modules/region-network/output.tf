output address_space {
    value                      = var.address_space
}

output bastion_fqdn {
    value                      = var.deploy_bastion ? azurerm_bastion_host.bastion.0.dns_name : null
}
output bastion_id {
    value                      = var.deploy_bastion ? azurerm_bastion_host.bastion.0.id : null
}
output diagnostics_storage_id {
    value                      = azurerm_storage_account.diagnostics.id
}

output egress_ip_address {
    value                      = var.deploy_nat_gateway ? azurerm_public_ip.egress.0.ip_address : null
}
output egress_ip_address_id {
    value                      = var.deploy_nat_gateway ? azurerm_public_ip.egress.0.id : null
}

output virtual_network_id {
    value                      = azurerm_virtual_network.region_network.id
}
output virtual_network_name {
    value                      = azurerm_virtual_network.region_network.name
}

output vm_subnet_id {
    value                      = azurerm_subnet.vm_subnet.id
}