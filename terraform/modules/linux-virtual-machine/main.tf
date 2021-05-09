locals {
  client_config                = {
    gitemail                   = var.git_email
    gitname                    = var.git_name
    workspace                  = terraform.workspace
  }

  diagnostics_storage_name     = element(split("/",var.diagnostics_storage_id),length(split("/",var.diagnostics_storage_id))-1)
  diagnostics_storage_rg       = element(split("/",var.diagnostics_storage_id),length(split("/",var.diagnostics_storage_id))-5)
  dns_zone_name                = var.dns_zone_id != null ? element(split("/",var.dns_zone_id),length(split("/",var.dns_zone_id))-1) : null
  dns_zone_rg                  = var.dns_zone_id != null ? element(split("/",var.dns_zone_id),length(split("/",var.dns_zone_id))-5) : null
  key_vault_name               = element(split("/",var.key_vault_id),length(split("/",var.key_vault_id))-1)
  key_vault_rg                 = element(split("/",var.key_vault_id),length(split("/",var.key_vault_id))-5)
  log_analytics_workspace_name = element(split("/",var.log_analytics_workspace_id),length(split("/",var.log_analytics_workspace_id))-1)
  log_analytics_workspace_rg   = element(split("/",var.log_analytics_workspace_id),length(split("/",var.log_analytics_workspace_id))-5)
  scripts_container_name       = element(split("/",var.scripts_container_id),length(split("/",var.scripts_container_id))-1)
  scripts_storage_name         = element(split(".",element(split("/",var.scripts_container_id),length(split("/",var.scripts_container_id))-2)),0)
  virtual_network_id           = join("/",slice(split("/",var.vm_subnet_id),0,length(split("/",var.vm_subnet_id))-2))

  environment_variables        = merge(
    {
      arm_subscription_id      = data.azurerm_client_config.current.subscription_id
      arm_tenant_id            = data.azurerm_client_config.current.tenant_id
      # Defaults, will be overriden by variables passed into map merge
      tf_backend_resource_group = ""
      tf_backend_storage_account= ""
      tf_backend_storage_container= ""
    },
    var.environment_variables
  )

  vm_name                      = "${var.resource_group_name}-${var.location}-${var.moniker}"
  computer_name                = substr(lower(replace("linux${var.location}","/a|e|i|o|u|y/","")),0,15)
}

data azurerm_client_config current {}

data azurerm_storage_account diagnostics {
  name                         = local.diagnostics_storage_name
  resource_group_name          = local.diagnostics_storage_rg
}

data azurerm_key_vault vault {
  name                         = local.key_vault_name
  resource_group_name          = local.key_vault_rg
}

data azurerm_log_analytics_workspace monitor {
  name                         = local.log_analytics_workspace_name
  resource_group_name          = local.log_analytics_workspace_rg
}

resource random_string pip_domain_name_label {
  length                      = 16
  upper                       = false
  lower                       = true
  number                      = false
  special                     = false
}

resource azurerm_public_ip pip {
  name                         = "${local.vm_name}-pip-nic"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  allocation_method            = "Static"
  sku                          = "Standard"
  domain_name_label            = random_string.pip_domain_name_label.result

  tags                         = var.tags
}

# Public DNS
resource azurerm_dns_a_record fqdn {
  name                         = replace(local.vm_name,"-${var.tags["suffix"]}","") # Canonical name
  zone_name                    = local.dns_zone_name
  resource_group_name          = local.dns_zone_rg
  ttl                          = 300
  target_resource_id           = azurerm_public_ip.pip.id

  tags                         = var.tags

  count                        = local.dns_zone_name != null ? 1 : 0
}

resource azurerm_network_interface nic {
  name                         = "${local.vm_name}-nic"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  ip_configuration {
    name                       = "ipconfig"
    subnet_id                  = var.vm_subnet_id
    primary                    = true
    private_ip_address_allocation = "dynamic"
    public_ip_address_id       = azurerm_public_ip.pip.id
  }
  enable_accelerated_networking = var.enable_accelerated_networking

  tags                         = var.tags
}

# Private DNS
resource azurerm_private_dns_a_record computer_name {
  name                         = local.computer_name
  zone_name                    = var.private_dns_zone
  resource_group_name          = var.resource_group_name
  ttl                          = 300
  records                      = [azurerm_network_interface.nic.private_ip_address]

  tags                         = var.tags
}
resource azurerm_private_dns_a_record vm_name {
  name                         = local.vm_name
  zone_name                    = var.private_dns_zone
  resource_group_name          = var.resource_group_name
  ttl                          = 300
  records                      = [azurerm_network_interface.nic.private_ip_address]

  tags                         = var.tags
}

resource azurerm_network_security_group nsg {
  name                         = "${var.resource_group_name}-${var.location}-linux-nsg"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  tags                         = var.tags
}

resource azurerm_network_security_rule admin_ssh {
  name                         = "AdminSSH${count.index+1}"
  priority                     = count.index+201
  direction                    = "Inbound"
  access                       = var.public_access_enabled ? "Allow" : "Deny"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "22"
  source_address_prefix        = var.admin_cidr_ranges[count.index]
  destination_address_prefix   = "*"
  resource_group_name          = azurerm_network_security_group.nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.nsg.name

  count                        = length(var.admin_cidr_ranges)

  depends_on                   = [
    null_resource.cloud_config_status # Close this port once we have obtained cloud init status via remote-provisioner
  ]
}

resource azurerm_network_security_rule terraform_ssh {
  name                         = "TerraformSSH"
  priority                     = 299
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "22"
  source_address_prefix        = var.terraform_cidr
  destination_address_prefix   = "*"
  resource_group_name          = azurerm_network_security_group.nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.nsg.name
}

resource azurerm_network_interface_security_group_association nic_nsg {
  network_interface_id         = azurerm_network_interface.nic.id
  network_security_group_id    = azurerm_network_security_group.nsg.id
}

# Cloud Init
data cloudinit_config user_data {
  gzip                         = false
  base64_encode                = false

  part {
    content                    = templatefile("${path.root}/../cloudinit/cloud-config-userdata.yaml",merge(
    {
      domain_suffix            = var.domain
      environment_ps1          = base64encode(templatefile("${path.module}/scripts/host/environment.ps1", local.environment_variables))
      host_name                = local.computer_name
      nic_domain_suffix        = azurerm_network_interface.nic.internal_domain_name_suffix
      private_ip_address       = azurerm_network_interface.nic.private_ip_address
      setup_linux_vm_ps1       = filebase64("${path.module}/scripts/host/setup_linux_vm.ps1")
      subnet_id                = var.vm_subnet_id
      user_name                = var.user_name
      virtual_network_id       = local.virtual_network_id
    },
    local.environment_variables
    ))
    content_type               = "text/cloud-config"
  }

  #merge_type                   = "list(append)+dict(recurse_array)+str()"
}

data azurerm_platform_image latest_image {
  location                     = var.location
  publisher                    = var.os_publisher
  offer                        = var.os_offer
  sku                          = var.os_sku
}

locals {
  # Workaround for:
  # BUG: https://github.com/terraform-providers/terraform-provider-azurerm/issues/6745
  os_version_latest            = element(split("/",data.azurerm_platform_image.latest_image.id),length(split("/",data.azurerm_platform_image.latest_image.id))-1)
  os_version                   = (var.os_version != null && var.os_version != "" && var.os_version != "latest") ? var.os_version : local.os_version_latest
}

resource azurerm_linux_virtual_machine vm {
  name                         = local.vm_name
  location                     = var.location
  resource_group_name          = var.resource_group_name
  size                         = var.vm_size
  admin_username               = var.user_name
  admin_password               = var.user_password
  disable_password_authentication = true
  encryption_at_host_enabled   = false # Requires confidential compute VM SKU
  network_interface_ids        = [azurerm_network_interface.nic.id]
  computer_name                = local.computer_name
  custom_data                  = base64encode(data.cloudinit_config.user_data.rendered)

  boot_diagnostics {
    storage_account_uri        = data.azurerm_storage_account.diagnostics.primary_blob_endpoint
  }

  admin_ssh_key {
    username                   = var.user_name
    public_key                 = file(var.ssh_public_key)
  }

  identity {
    type                       = "SystemAssigned, UserAssigned"
    identity_ids               = [var.user_assigned_identity_id]
  }

  os_disk {
    caching                    = "ReadWrite"
    storage_account_type       = "Premium_LRS"
  }

  source_image_reference {
    publisher                  = var.os_publisher
    offer                      = var.os_offer
    sku                        = var.os_sku
    version                    = local.os_version
  }

  tags                         = var.tags
  depends_on                   = [
    azurerm_private_dns_a_record.computer_name,
    azurerm_network_interface_security_group_association.nic_nsg
  ]
  lifecycle {
    ignore_changes             = [
      # Let bootstrap-os update the host configuration
      custom_data
    ]
  }  
}

resource null_resource start_vm {
  # Always run this
  triggers                     = {
    always_run                 = timestamp()
  }

  provisioner local-exec {
    # Start VM, so we can make changes
    command                    = "az vm start --ids ${azurerm_linux_virtual_machine.vm.id}"
  }
}

resource azurerm_virtual_machine_extension cloud_config_status {
  name                         = "CloudConfigStatusScript"
  virtual_machine_id           = azurerm_linux_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.Extensions"
  type                         = "CustomScript"
  type_handler_version         = "2.0"
  settings                     = jsonencode({
    "commandToExecute"         = "/usr/bin/cloud-init status --long --wait ; systemctl status cloud-final.service --full --no-pager --wait"
  })
  tags                         = var.tags

  depends_on                   = [null_resource.start_vm]
}

resource null_resource cloud_config_status {
  triggers                     = {
    vm                         = azurerm_linux_virtual_machine.vm.id
  }

  # Get cloud-init status, waiting for completion if needed
  provisioner remote-exec {
    inline                     = [
      "echo -n 'waiting for cloud-init to complete'",
      "/usr/bin/cloud-init status --long --wait >/dev/null", # Let Terraform print progress
      "systemctl status cloud-final.service --full --no-pager --wait"
    ]

    connection {
      type                     = "ssh"
      user                     = var.user_name
      # password                 = var.user_password
      private_key              = file(var.ssh_private_key)
      host                     = azurerm_public_ip.pip.ip_address
    }
  }

  depends_on                   = [
    azurerm_virtual_machine_extension.cloud_config_status,
    azurerm_network_interface_security_group_association.nic_nsg,
    azurerm_network_security_rule.terraform_ssh,
  ]
}

resource azurerm_virtual_machine_extension log_analytics {
  name                         = "OmsAgentForLinux"
  virtual_machine_id           = azurerm_linux_virtual_machine.vm.id
  publisher                    = "Microsoft.EnterpriseCloud.Monitoring"
  type                         = "OmsAgentForLinux"
  type_handler_version         = "1.7"
  auto_upgrade_minor_version   = true
  settings                     = jsonencode({
    "workspaceId"              = data.azurerm_log_analytics_workspace.monitor.workspace_id
  })
  protected_settings           = jsonencode({
    "workspaceKey"             = data.azurerm_log_analytics_workspace.monitor.primary_shared_key
  })

  tags                         = var.tags
  depends_on                   = [azurerm_virtual_machine_extension.cloud_config_status]
}

# resource azurerm_virtual_machine_extension azure_monitor {
#   name                         = "AzureMonitorLinuxAgent"
#   virtual_machine_id           = azurerm_linux_virtual_machine.vm.id
#   publisher                    = "Microsoft.Azure.Monitor"
#   type                         = "AzureMonitorLinuxAgent"
#   type_handler_version         = "1.5"
#   auto_upgrade_minor_version   = true

#   tags                         = var.tags
#   depends_on                   = [azurerm_virtual_machine_extension.log_analytics]
# }

resource azurerm_virtual_machine_extension aad_login {
  name                         = "AADLoginForLinux"
  virtual_machine_id           = azurerm_linux_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.ActiveDirectory.LinuxSSH"
  type                         = "AADLoginForLinux"
  type_handler_version         = "1.0"
  auto_upgrade_minor_version   = true

  tags                         = var.tags
  depends_on                   = [azurerm_virtual_machine_extension.log_analytics]
  count                        = var.enable_aad_login ? 1 : 0
} 

resource azurerm_virtual_machine_extension dependency_monitor {
  name                         = "DAExtension"
  virtual_machine_id           = azurerm_linux_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                         = "DependencyAgentLinux"
  type_handler_version         = "9.5"
  auto_upgrade_minor_version   = true

  count                        = var.dependency_monitor ? 1 : 0
  tags                         = var.tags
  depends_on                   = [azurerm_virtual_machine_extension.log_analytics]
}
resource azurerm_virtual_machine_extension network_watcher {
  name                         = "AzureNetworkWatcherExtension"
  virtual_machine_id           = azurerm_linux_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.NetworkWatcher"
  type                         = "NetworkWatcherAgentLinux"
  type_handler_version         = "1.4"
  auto_upgrade_minor_version   = true

  count                        = var.network_watcher ? 1 : 0
  tags                         = var.tags
  depends_on                   = [azurerm_virtual_machine_extension.log_analytics]
}

resource azurerm_key_vault_key disk_encryption_key {
  name                         = "${local.vm_name}-disk-key"
  key_vault_id                 = var.key_vault_id
  key_type                     = "RSA"
  key_size                     = 2048
  key_opts                     = [
                                 "decrypt",
                                 "encrypt",
                                 "sign",
                                 "unwrapKey",
                                 "verify",
                                 "wrapKey",
  ]
}

# Delay DiskEncryption to mitigate race condition
resource time_sleep vm_sleep {
  create_duration              = "1000s"

  count                        = var.disk_encryption ? 1 : 0
  depends_on                   = [
                                  azurerm_virtual_machine_extension.aad_login,
                                  # azurerm_virtual_machine_extension.azure_monitor,
                                  azurerm_virtual_machine_extension.dependency_monitor,
                                  azurerm_virtual_machine_extension.log_analytics,
                                  azurerm_virtual_machine_extension.network_watcher
  ]
}

resource azurerm_virtual_machine_extension disk_encryption {
  name                         = "DiskEncryption"
  virtual_machine_id           = azurerm_linux_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.Security"
  type                         = "AzureDiskEncryptionForLinux"
  type_handler_version         = "1.1"
  auto_upgrade_minor_version   = true

  settings                     = jsonencode({
    "EncryptionOperation"      = "EnableEncryption"
    "KeyVaultURL"              = data.azurerm_key_vault.vault.vault_uri
    "KeyVaultResourceId"       = data.azurerm_key_vault.vault.id
    "KeyEncryptionKeyURL"      = "${data.azurerm_key_vault.vault.vault_uri}keys/${azurerm_key_vault_key.disk_encryption_key.name}/${azurerm_key_vault_key.disk_encryption_key.version}"
    "KekVaultResourceId"       = data.azurerm_key_vault.vault.id
    "KeyEncryptionAlgorithm"   = "RSA-OAEP"
    "VolumeType"               = "All"
  })

  count                        = var.disk_encryption ? 1 : 0
  tags                         = var.tags

  depends_on                   = [
                                  time_sleep.vm_sleep
  ]
}
# az vm encryption show --ids ${self.id} -o table
# az vm encryption show --ids $(az vm list -g dev-default-cris --subscription $env:ARM_SUBSCRIPTION_ID --query "[].id" -o tsv) --query "[].{name:disks[0].name, status:disks[0].statuses[0].displayStatus}" -o table

resource azurerm_dev_test_global_vm_shutdown_schedule auto_shutdown {
  virtual_machine_id           = azurerm_linux_virtual_machine.vm.id
  location                     = azurerm_linux_virtual_machine.vm.location
  enabled                      = true

  daily_recurrence_time        = var.shutdown_time
  timezone                     = var.timezone

  notification_settings {
    enabled                    = false
  }

  tags                         = var.tags
  count                        = var.shutdown_time != null && var.shutdown_time != "" ? 1 : 0
}

# HACK: Use this as the last resource created for a VM, so we can set a destroy action to happen prior to VM (extensions) destroy
resource azurerm_monitor_diagnostic_setting vm {
  name                         = "${azurerm_linux_virtual_machine.vm.name}-diagnostics"
  target_resource_id           = azurerm_linux_virtual_machine.vm.id
  storage_account_id           = var.diagnostics_storage_id

  metric {
    category                   = "AllMetrics"

    retention_policy {
      enabled                  = false
    }
  }

  # Start VM, so we can destroy VM extensions
  provisioner local-exec {
    command                    = "az vm start --ids ${self.target_resource_id}"
    when                       = destroy
  }

  depends_on                   = [
                                  azurerm_virtual_machine_extension.aad_login,
                                  # azurerm_virtual_machine_extension.azure_monitor,
                                  azurerm_virtual_machine_extension.dependency_monitor,
                                  azurerm_virtual_machine_extension.disk_encryption,
                                  azurerm_virtual_machine_extension.log_analytics,
                                  azurerm_virtual_machine_extension.network_watcher
  ]
}
