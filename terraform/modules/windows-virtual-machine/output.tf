output computer_name {
    value                      = local.computer_name
}
output name {
    value                      = azurerm_windows_virtual_machine.vm.name
}
output os_version {
    value                      = local.os_version
}
output os_version_latest {
    value                      = local.os_version_latest
}
output private_fqdn {
    value                      = local.private_fqdn
}
output private_ip_address {
    value                      = azurerm_network_interface.nic.private_ip_address
}
output public_ip_id {
    value                      = azurerm_public_ip.pip.id
}
output public_ip_address {
    value                      = azurerm_public_ip.pip.ip_address
}
output public_fqdn {
    value                      = local.public_fqdn
}

output vm_id {
    value                      = azurerm_windows_virtual_machine.vm.id
}
