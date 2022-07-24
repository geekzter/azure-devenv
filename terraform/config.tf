locals {
  connect_vm_script              = templatefile("${path.root}/scripts/connect_vm.ps1",
  {
    bastion_id                   = var.deploy_bastion ? module.region_network[azurerm_resource_group.vm_resource_group.location].bastion_id : "$null"
    default_location             = azurerm_resource_group.vm_resource_group.location
    linux_virtual_machine_data   = local.linux_virtual_machine_data
    locations                    = var.locations
    resource_group_id            = azurerm_resource_group.vm_resource_group.id
    ssh_private_key              = var.ssh_private_key
    tenant_id                    = data.azuread_client_config.current.tenant_id
    user_name                    = var.admin_username
    windows_virtual_machine_data = local.windows_virtual_machine_data
  })
  linux_virtual_machine_data     = jsonencode({
    for vm in module.linux_vm : vm.location => {
      id                         : vm.vm_id,
      public_fqdn                : vm.public_fqdn,
      public_ip_address          : vm.public_ip_address
      private_fqdn               : vm.private_fqdn,
      private_ip_address         : vm.private_ip_address
    }
  })
  windows_virtual_machine_data  = jsonencode({
    for vm in module.windows_vm : vm.location => {
      id                         : vm.vm_id,
      public_fqdn                : vm.public_fqdn,
      public_ip_address          : vm.public_ip_address
      private_fqdn               : vm.private_fqdn,
      private_ip_address         : vm.private_ip_address
    }
  })
}

resource azurerm_storage_container configuration {
  name                         = "configuration"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  container_access_type        = "private"
}

resource azurerm_storage_blob terraform_backend_configuration {
  name                         = "terraform/backend.tf"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.configuration.name
  type                         = "Block"
  source                       = "${path.root}/backend.tf"

  count                        = var.configure_access_control && fileexists("${path.root}/backend.tf") ? 1 : 0
  depends_on                   = [azurerm_role_assignment.terraform_storage_owner]
}

resource azurerm_storage_blob terraform_auto_vars_configuration {
  name                         = "terraform/config.auto.tfvars"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.configuration.name
  type                         = "Block"
  source                       = "${path.root}/config.auto.tfvars"

  count                        = var.configure_access_control && fileexists("${path.root}/config.auto.tfvars") ? 1 : 0
  depends_on                   = [azurerm_role_assignment.terraform_storage_owner]
}

resource azurerm_storage_blob terraform_workspace_vars_configuration {
  name                         = "terraform/${terraform.workspace}.tfvars"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.configuration.name
  type                         = "Block"
  source                       = "${path.root}/${terraform.workspace}.tfvars"

  count                        = var.configure_access_control && fileexists("${path.root}/${terraform.workspace}.tfvars") ? 1 : 0
  depends_on                   = [azurerm_role_assignment.terraform_storage_owner]
}

resource azurerm_storage_blob connect_vm_script {
  name                         = "data/${terraform.workspace}/connect_vm.ps1"
  storage_account_name         = azurerm_storage_account.automation_storage.name
  storage_container_name       = azurerm_storage_container.configuration.name
  type                         = "Block"
  source_content               = local.connect_vm_script

  depends_on                   = [azurerm_role_assignment.terraform_storage_owner]
}
resource local_file connect_vm_script {
  content                      = local.connect_vm_script
  filename                     = "${path.root}/../data/${terraform.workspace}/connect_vm.ps1"
}