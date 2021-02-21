output address_space {
    value                      = var.address_space
}

output diagnostics_storage_id {
    value                      = azurerm_storage_account.diagnostics_storage.id
}

output egress_ip_address {
    value                      = azurerm_public_ip.egress.ip_address
}
output egress_ip_address_id {
    value                      = azurerm_public_ip.egress.id
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