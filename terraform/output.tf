output admin_password {
    sensitive                  = true
    value                      = local.password
}
output admin_username {
    sensitive                  = false
    value                      = var.admin_username
}
output resource_group_id {
    value                      = azurerm_resource_group.vm_resource_group.id
}
output resource_group_name {
    value                      = azurerm_resource_group.vm_resource_group.name
}
output windows_fqdn {
    value                      = replace(azurerm_dns_cname_record.windows_fqdn.fqdn,"/\\W*$/","")
}