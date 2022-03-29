resource local_file linux_bastion_script {
  content                      = templatefile("${path.root}/scripts/connect_linux_vm.ps1",
  {
    bastion_name               = module.region_network[azurerm_resource_group.vm_resource_group.location].bastion_name
    private_ip_address         = module.linux_vm[each.value].public_ip_address
    private_fqdn               = module.linux_vm[each.value].public_fqdn
    public_ip_address          = module.linux_vm[each.value].public_ip_address
    public_fqdn                = module.linux_vm[each.value].public_fqdn
    resource_group_name        = azurerm_resource_group.vm_resource_group.name
    user_name                  = var.admin_username
    ssh_private_key            = var.ssh_private_key
    subscription_id            = split("/",azurerm_resource_group.vm_resource_group.id)[2]
    vm_id                      = module.linux_vm[each.value].vm_id
  })
  filename                     = "${path.root}/../data/${terraform.workspace}/connect_linux_vm_${each.value}.ps1"

  for_each                     = var.deploy_bastion ? toset(var.locations) : toset([])
}