output vm_id {
    value                      = azurerm_windows_virtual_machine.vm.id
}
output private_ip_address {
    value                      = azurerm_network_interface.vm_if.private_ip_address
}
output public_ip_address {
    value                      = azurerm_public_ip.vm_pip.ip_address
}
output public_fqdn {
    value                      = azurerm_public_ip.vm_pip.fqdn
}