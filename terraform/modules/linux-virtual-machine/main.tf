locals {
  client_config                = map(
    "gitemail",                  var.git_email,
    "gitname",                   var.git_name,
    "workspace",                 terraform.workspace
  )

  diagnostics_storage_name     = element(split("/",var.diagnostics_storage_id),length(split("/",var.diagnostics_storage_id))-1)
  diagnostics_storage_rg       = element(split("/",var.diagnostics_storage_id),length(split("/",var.diagnostics_storage_id))-5)
  dns_zone_name                = var.dns_zone_id != null ? element(split("/",var.dns_zone_id),length(split("/",var.dns_zone_id))-1) : null
  dns_zone_rg                  = var.dns_zone_id != null ? element(split("/",var.dns_zone_id),length(split("/",var.dns_zone_id))-5) : null
  key_vault_name               = element(split("/",var.key_vault_id),length(split("/",var.key_vault_id))-1)
  key_vault_rg                 = element(split("/",var.key_vault_id),length(split("/",var.key_vault_id))-5)
  log_analytics_workspace_name = var.log_analytics_workspace_id != null ? element(split("/",var.log_analytics_workspace_id),length(split("/",var.log_analytics_workspace_id))-1) : null
  log_analytics_workspace_rg   = var.log_analytics_workspace_id != null ? element(split("/",var.log_analytics_workspace_id),length(split("/",var.log_analytics_workspace_id))-5) : null
  scripts_container_name       = element(split("/",var.scripts_container_id),length(split("/",var.scripts_container_id))-1)
  scripts_storage_name         = element(split(".",element(split("/",var.scripts_container_id),length(split("/",var.scripts_container_id))-2)),0)

  environment_variables        = merge(
    map(
      "arm_subscription_id",     data.azurerm_client_config.current.subscription_id,
      "arm_tenant_id",           data.azurerm_client_config.current.tenant_id,
      # Defaults, will be overriden by variables passed into map merge
      "tf_backend_resource_group", "",
      "tf_backend_storage_account", "",
      "tf_backend_storage_container", "",
    ),
    var.environment_variables
  )

  vm_name                      = "${data.azurerm_resource_group.vm_resource_group.name}-${var.location}-${var.moniker}"
  computer_name                = substr(lower(replace("linux${var.location}","/a|e|i|o|u|y/","")),0,15)
}

data azurerm_client_config current {}

data azurerm_resource_group vm_resource_group {
  name                         = var.resource_group_name
}

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

  count                        = local.log_analytics_workspace_name != null ? 1 : 0
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
  resource_group_name          = data.azurerm_resource_group.vm_resource_group.name
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
  resource_group_name          = data.azurerm_resource_group.vm_resource_group.name

  ip_configuration {
    name                       = "ipconfig"
    subnet_id                  = var.vm_subnet_id
    private_ip_address_allocation = "Dynamic"
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
  name                         = "${data.azurerm_resource_group.vm_resource_group.name}-${var.location}-linux-nsg"
  location                     = var.location
  resource_group_name          = data.azurerm_resource_group.vm_resource_group.name

  security_rule {
    name                       = "InboundSSH"
    priority                   = 202
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags                         = var.tags
}

resource azurerm_network_interface_security_group_association nic_nsg {
  network_interface_id         = azurerm_network_interface.nic.id
  network_security_group_id    = azurerm_network_security_group.nsg.id
}

data external image_info {
  program                      = [
                                 "az",
                                 "vm",
                                 "image",
                                 "list",
                                 "-f",
                                 var.os_offer,
                                 "-p",
                                 var.os_publisher,
                                 "--all",
                                 "--query",
                                 # Get latest version of matching SKU
                                 "max_by([?contains(sku,'${var.os_sku}')],&version)",
                                 "-o",
                                 "json",
                                 ]
}

locals {
  # data.external.image_info.result.sku should be same as 'latest' 
  # This allows to override the version value with the literal version, and don't trigger a change if resolving to the same
  os_version                   = (var.os_version != null && var.os_version != "" && var.os_version != "latest") ? var.os_version : data.external.image_info.result.version
}

# Cloud Init
data cloudinit_config user_data {
  gzip                         = false
  base64_encode                = false

  part {
    content                    = templatefile("${path.module}/scripts/host/cloud-config-userdata.yaml",merge(
    {
      domain_suffix            = var.domain
      environment_ps1          = base64encode(templatefile("${path.module}/scripts/host/environment.ps1", local.environment_variables))
      host_name                = local.computer_name
      nic_domain_suffix        = azurerm_network_interface.nic.internal_domain_name_suffix
      private_ip_address       = azurerm_network_interface.nic.private_ip_address
      setup_linux_vm_ps1       = filebase64("${path.module}/scripts/host/setup_linux_vm.ps1")
      user_name                = var.user_name
    },
    local.environment_variables
    ))
    content_type               = "text/cloud-config"
  }

  #merge_type                   = "list(append)+dict(recurse_array)+str()"
}

resource azurerm_linux_virtual_machine vm {
  name                         = local.vm_name
  location                     = var.location
  resource_group_name          = data.azurerm_resource_group.vm_resource_group.name
  size                         = var.vm_size
  admin_username               = var.user_name
  admin_password               = var.user_password
  disable_password_authentication = false
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
}

resource null_resource start_vm {
  # Always run this
  triggers                     = {
    always_run                 = timestamp()
  }

  provisioner local-exec {
    # Start VM, so we can execute script through SSH
    command                    = "az vm start --ids ${azurerm_linux_virtual_machine.vm.id}"
  }
}

resource null_resource cloud_config_status {
  triggers                     = {
    # always                     = timestamp()
    vm                         = azurerm_linux_virtual_machine.vm.id
  }

  # Get cloud-init status, waiting for completion if needed
  provisioner remote-exec {
    inline                     = [
      "echo -n 'waiting for cloud-init to complete'",
      "/usr/bin/cloud-init status -l --wait",
      "systemctl status cloud-final.service --no-pager -l --wait"
    ]

    connection {
      type                     = "ssh"
      user                     = var.user_name
      password                 = var.user_password
      host                     = azurerm_public_ip.pip.ip_address
    }
  }

  depends_on                   = [
    null_resource.start_vm,
    azurerm_network_interface_security_group_association.nic_nsg,
    # azurerm_monitor_diagnostic_setting.vm
  ]
}

/*
resource azurerm_virtual_machine_extension vm_monitor {
  name                         = "MMAExtension"
  virtual_machine_id           = azurerm_linux_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.Monitor"
  type                         = "AzureMonitorLinuxAgent"
  type_handler_version         = "0.9"
  auto_upgrade_minor_version   = true
  settings                     = <<EOF
    {
      "workspaceId"            : "${data.azurerm_log_analytics_workspace.monitor.workspace_id}",
      "azureResourceId"        : "${azurerm_linux_virtual_machine.vm.id}",
      "stopOnMultipleConnections": "true"
    }
  EOF
  protected_settings = <<EOF
    { 
      "workspaceKey"           : "${data.azurerm_log_analytics_workspace.monitor.primary_shared_key}"
    } 
  EOF

  count                        = var.log_analytics_workspace_id != null ? 1 : 0
  tags                         = var.tags
  depends_on                   = [null_resource.start_vm]
}
*/

resource azurerm_virtual_machine_extension vm_aadlogin {
  name                         = "AADLoginForLinux"
  virtual_machine_id           = azurerm_linux_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.ActiveDirectory.LinuxSSH"
  type                         = "AADLoginForLinux"
  type_handler_version         = "1.0"
  auto_upgrade_minor_version   = true

  tags                         = var.tags
  depends_on                   = [
                                  null_resource.start_vm,
                                  null_resource.cloud_config_status
                                 ]

  count                        = var.enable_aad_login ? 1 : 0
} 

/*
resource azurerm_virtual_machine_extension vm_diagnostics {
  name                         = "Microsoft.Insights.VMDiagnosticsSettings"
  virtual_machine_id           = azurerm_linux_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.Diagnostics"
  type                         = "IaaSDiagnostics"
  type_handler_version         = "1.17"
  auto_upgrade_minor_version   = true

  settings                     = templatefile("${path.module}/scripts/host/vmdiagnostics.json", { 
    storage_account_name       = data.azurerm_storage_account.diagnostics.name, 
    virtual_machine_id         = azurerm_linux_virtual_machine.vm.id, 
  # application_insights_key   = azurerm_application_insights.app_insights.instrumentation_key
  })

  protected_settings = <<EOF
    { 
      "storageAccountName"     : "${data.azurerm_storage_account.diagnostics.name}",
      "storageAccountKey"      : "${data.azurerm_storage_account.diagnostics.primary_access_key}",
      "storageAccountEndPoint" : "https://core.windows.net"
    } 
  EOF

  count                        = var.diagnostics ? 1 : 0
  tags                         = var.tags
  depends_on                   = [
                                  null_resource.start_vm
                                 ]
}
*/
resource azurerm_virtual_machine_extension vm_dependency_monitor {
  name                         = "DAExtension"
  virtual_machine_id           = azurerm_linux_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                         = "DependencyAgentLinux"
  type_handler_version         = "9.5"
  auto_upgrade_minor_version   = true
  settings                     = <<EOF
    {
      "workspaceId"            : "${data.azurerm_log_analytics_workspace.monitor.0.id}"
    }
  EOF

  protected_settings = <<EOF
    { 
      "workspaceKey"           : "${data.azurerm_log_analytics_workspace.monitor.0.primary_shared_key}"
    } 
  EOF

  count                        = var.dependency_monitor && local.log_analytics_workspace_name != null ? 1 : 0
  tags                         = var.tags
  depends_on                   = [
                                  null_resource.start_vm,
                                  null_resource.cloud_config_status
                                 ]
}
resource azurerm_virtual_machine_extension vm_watcher {
  name                         = "AzureNetworkWatcherExtension"
  virtual_machine_id           = azurerm_linux_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.NetworkWatcher"
  type                         = "NetworkWatcherAgentLinux"
  type_handler_version         = "1.4"
  auto_upgrade_minor_version   = true

  count                        = var.network_watcher ? 1 : 0
  tags                         = var.tags
  depends_on                   = [
                                  null_resource.start_vm,
                                  null_resource.cloud_config_status
                                 ]
}

# Delay DiskEncryption to mitigate race condition
resource null_resource vm_sleep {
  # Always run this
  triggers                     = {
    vm                         = azurerm_linux_virtual_machine.vm.id
  }

  provisioner "local-exec" {
    command                    = "Start-Sleep 300"
    interpreter                = ["pwsh", "-nop", "-Command"]
  }

  count                        = var.disk_encryption ? 1 : 0
  depends_on                   = [azurerm_linux_virtual_machine.vm]
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

# Does not work with AutoLogon
# use server side encryption with azurerm_disk_encryption_set instead
resource azurerm_virtual_machine_extension vm_disk_encryption {
  name                         = "DiskEncryption"
  virtual_machine_id           = azurerm_linux_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.Security"
  type                         = "AzureDiskEncryption"
  type_handler_version         = "2.2"
  auto_upgrade_minor_version   = true

  settings = <<SETTINGS
    {
      "EncryptionOperation"    : "EnableEncryption",
      "KeyVaultURL"            : "${data.azurerm_key_vault.vault.vault_uri}",
      "KeyVaultResourceId"     : "${data.azurerm_key_vault.vault.id}",
      "KeyEncryptionKeyURL"    : "${data.azurerm_key_vault.vault.vault_uri}keys/${azurerm_key_vault_key.disk_encryption_key.name}/${azurerm_key_vault_key.disk_encryption_key.version}",       
      "KekVaultResourceId"     : "${data.azurerm_key_vault.vault.id}",
      "KeyEncryptionAlgorithm" : "RSA-OAEP",
      "VolumeType"             : "All"
    }
SETTINGS

  count                        = var.disk_encryption ? 1 : 0
  tags                         = var.tags

  depends_on                   = [
                                  null_resource.start_vm,
                                  null_resource.cloud_config_status,
                                  null_resource.vm_sleep
                                 ]
}

# HACK: Use this as the last resource created for a VM, so we can set a destroy action to happen prior to VM (extensions) destroy
resource azurerm_monitor_diagnostic_setting vm {
  name                         = "${azurerm_linux_virtual_machine.vm.name}-diagnostics"
  target_resource_id           = azurerm_linux_virtual_machine.vm.id
  storage_account_id           = data.azurerm_storage_account.diagnostics.id

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
                                  azurerm_virtual_machine_extension.vm_aadlogin,
                                  azurerm_virtual_machine_extension.vm_dependency_monitor,
                                  #azurerm_virtual_machine_extension.vm_diagnostics,
                                  azurerm_virtual_machine_extension.vm_disk_encryption,
                                  # azurerm_virtual_machine_extension.vm_monitor,
                                  azurerm_virtual_machine_extension.vm_watcher
  ]
}
