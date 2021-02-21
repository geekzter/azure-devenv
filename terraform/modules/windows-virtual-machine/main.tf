locals {
  client_config                = map(
    "gitemail",                  var.git_email,
    "gitname",                   var.git_name,
    "scripturl",                 local.script_url,
    "environmentscripturl",      local.environment_script_url,
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

  # Hide dependency on script blobs, so we prevent VM re-creation if script changes
  environment_filename         = "environment"
  environment_script_url       = "${var.scripts_container_id}/${local.environment_filename}_${var.location}.ps1"
  script_filename              = "setup_windows_vm"
  script_url                   = "${var.scripts_container_id}/${local.script_filename}_${var.location}.ps1"

  private_fqdn                 = replace(azurerm_private_dns_a_record.computer_name.fqdn,"/\\W*$/","")
  public_fqdn                  = local.dns_zone_rg != null ? replace(azurerm_dns_a_record.fqdn.0.fqdn,"/\\W*$/","") : azurerm_public_ip.pip.fqdn

  vm_name                      = "${data.azurerm_resource_group.vm_resource_group.name}-${var.location}-${var.moniker}"
  computer_name                = substr(lower(replace("windows${var.location}","/a|e|i|o|u|y/","")),0,15)
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

resource time_static vm_update {
  triggers = {
    # Save the time each switch of an VM NIC
    nic_id                   = azurerm_network_interface.nic.id
    vm_id                      = azurerm_windows_virtual_machine.vm.id
  }
}

resource random_string pip_domain_name_label {
  length                      = 16
  upper                       = false
  lower                       = true
  number                      = false
  special                     = false
}

resource azurerm_public_ip pip {
  name                         = "${local.vm_name}-pip"
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
  name                         = "${local.vm_name}-if"
  location                     = var.location
  resource_group_name          = data.azurerm_resource_group.vm_resource_group.name

  ip_configuration {
    name                       = "vm_ipconfig"
    subnet_id                  = var.vm_subnet_id
    public_ip_address_id       = azurerm_public_ip.pip.id
    private_ip_address_allocation = "dynamic"
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
  name                         = "${data.azurerm_resource_group.vm_resource_group.name}-${var.location}-windows-nsg"
  location                     = var.location
  resource_group_name          = data.azurerm_resource_group.vm_resource_group.name

  tags                         = var.tags
}

resource azurerm_network_security_rule rdp {
  name                         = "InboundRDP${count.index+1}"
  priority                     = count.index+201
  direction                    = "Inbound"
  access                       = var.public_access_enabled ? "Allow" : "Deny"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "3389"
  source_address_prefix        = var.admin_cidr_ranges[count.index]
  destination_address_prefix   = "*"
  resource_group_name          = azurerm_network_security_group.nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.nsg.name

  count                        = length(var.admin_cidr_ranges)
}

resource azurerm_network_interface_security_group_association nic_nsg {
  network_interface_id         = azurerm_network_interface.nic.id
  network_security_group_id    = azurerm_network_security_group.nsg.id
}

resource azurerm_storage_blob setup_windows_vm_cmd {
  name                         = "${local.script_filename}_${var.location}.cmd"
  storage_account_name         = local.scripts_storage_name
  storage_container_name       = local.scripts_container_name

  type                         = "Block"
  source_content               = templatefile("${path.module}/scripts/host/${local.script_filename}.cmd", { 
    scripturl                  = local.script_url
  })
}

resource azurerm_storage_blob setup_windows_vm_ps1 {
  name                         = "${local.script_filename}_${var.location}.ps1"
  storage_account_name         = local.scripts_storage_name
  storage_container_name       = local.scripts_container_name

  type                         = "Block"
  # Use source_content to trigger change when file changes
  source_content               = file("${path.module}/scripts/host/${local.script_filename}.ps1")
}

resource azurerm_storage_blob environment_ps1 {
  name                         = "${local.environment_filename}_${var.location}.ps1"
  storage_account_name         = local.scripts_storage_name
  storage_container_name       = local.scripts_container_name

  type                         = "Block"
  source_content               = templatefile("${path.module}/scripts/host/${local.environment_filename}.ps1", local.environment_variables)
}

# Adapted from https://github.com/Azure/terraform-azurerm-diskencrypt/blob/master/main.tf
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

# depends_on                   = [azurerm_firewall_application_rule_collection.*]
}

data azurerm_platform_image latest_image {
  location                     = var.location
  publisher                    = local.os_publisher
  offer                        = local.os_offer
  sku                          = var.os_sku
  # version                      = (var.os_version != null && var.os_version != "" && var.os_version != "latest") ? var.os_version : "latest"
}

locals {
  # Workaround for:
  # BUG: https://github.com/terraform-providers/terraform-provider-azurerm/issues/6745
  os_offer                     = "Windows-10"
  os_publisher                 = "MicrosoftWindowsDesktop"
  os_version_latest            = element(split("/",data.azurerm_platform_image.latest_image.id),length(split("/",data.azurerm_platform_image.latest_image.id))-1)
  os_version                   = (var.os_version != null && var.os_version != "" && var.os_version != "latest") ? var.os_version : local.os_version_latest
}

resource azurerm_windows_virtual_machine vm {
  name                         = local.vm_name
  location                     = var.location
  resource_group_name          = data.azurerm_resource_group.vm_resource_group.name
  network_interface_ids        = [azurerm_network_interface.nic.id]
  size                         = var.vm_size
  admin_username               = var.admin_username
  admin_password               = var.admin_password
  computer_name                = local.computer_name

  os_disk {
    name                       = "${local.vm_name}-osdisk"
    caching                    = "ReadWrite"
    storage_account_type       = "Premium_LRS"
  }

  # BUG: https://github.com/terraform-providers/terraform-provider-azurerm/issues/6745
  # source_image_id              = local.vm_image_id
  source_image_reference {
    publisher                  = local.os_publisher
    offer                      = local.os_offer
    sku                        = var.os_sku
    version                    = local.os_version
  }

  # TODO: Does not work with AzureDiskEncryption VM extension
  additional_unattend_content {
    setting                    = "AutoLogon"
    content                    = templatefile("${path.module}/scripts/host/AutoLogon.xml", { 
      count                    = 99, 
      username                 = var.admin_username, 
      password                 = var.admin_password
    })
  }
  additional_unattend_content {
    setting                    = "FirstLogonCommands"
    content                    = templatefile("${path.module}/scripts/host/FirstLogonCommands.xml", { 
      username                 = var.admin_username, 
      password                 = var.admin_password, 
      scripturl                = local.script_url
    })
  }

  custom_data                  = base64encode(jsonencode(local.client_config))

  # Required for AAD Login
  identity {
    type                       = "SystemAssigned"
  }

# depends_on                   = [azurerm_firewall_application_rule_collection.*]
  tags                         = var.tags
}

resource null_resource start_vm {
  # Always run this
  triggers                     = {
    always_run                 = timestamp()
  }

  provisioner local-exec {
    # Start VM, so we can execute script through SSH
    command                    = "az vm start --ids ${azurerm_windows_virtual_machine.vm.id}"
  }
}

resource azurerm_virtual_machine_extension azure_monitor {
  name                         = "AzureMonitorWindowsAgent"
  virtual_machine_id           = azurerm_windows_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.Monitor"
  type                         = "AzureMonitorWindowsAgent"
  type_handler_version         = "1.0"
  auto_upgrade_minor_version   = true

  tags                         = var.tags
  depends_on                   = [null_resource.start_vm]
}

resource azurerm_virtual_machine_extension log_analytics {
  name                         = "MMAExtension"
  virtual_machine_id           = azurerm_windows_virtual_machine.vm.id
  publisher                    = "Microsoft.EnterpriseCloud.Monitoring"
  type                         = "MicrosoftMonitoringAgent"
  type_handler_version         = "1.0"
  auto_upgrade_minor_version   = true
  settings                     = <<EOF
    {
      "workspaceId"            : "${data.azurerm_log_analytics_workspace.monitor.0.workspace_id}",
      "azureResourceId"        : "${azurerm_windows_virtual_machine.vm.id}",
      "stopOnMultipleConnections": "true"
    }
  EOF
  protected_settings = <<EOF
    { 
      "workspaceKey"           : "${data.azurerm_log_analytics_workspace.monitor.0.primary_shared_key}"
    } 
  EOF

  count                        = var.log_analytics_workspace_id != null ? 1 : 0
  tags                         = var.tags
  depends_on                   = [
                                  null_resource.start_vm,
                                  azurerm_virtual_machine_extension.azure_monitor
                                 ]
}

resource azurerm_virtual_machine_extension vm_aadlogin {
  name                         = "AADLoginForWindows"
  virtual_machine_id           = azurerm_windows_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.ActiveDirectory"
  type                         = "AADLoginForWindows"
  type_handler_version         = "1.0"
  auto_upgrade_minor_version   = true

  count                        = var.aad_login ? 1 : 0
  tags                         = var.tags
  depends_on                   = [
                                  null_resource.start_vm,
                                  azurerm_virtual_machine_extension.azure_monitor
                                 ]
} 

resource azurerm_virtual_machine_extension vm_bginfo {
  name                         = "BGInfo"
  virtual_machine_id           = azurerm_windows_virtual_machine.vm.id
  publisher                    = "Microsoft.Compute"
  type                         = "BGInfo"
  type_handler_version         = "2.1"
  auto_upgrade_minor_version   = true

  count                        = var.bg_info ? 1 : 0
  tags                         = var.tags
  depends_on                   = [
                                  null_resource.start_vm,
                                  azurerm_virtual_machine_extension.azure_monitor
                                 ]
}

resource azurerm_virtual_machine_extension vm_diagnostics {
  name                         = "Microsoft.Insights.VMDiagnosticsSettings"
  virtual_machine_id           = azurerm_windows_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.Diagnostics"
  type                         = "IaaSDiagnostics"
  type_handler_version         = "1.17"
  auto_upgrade_minor_version   = true

  settings                     = templatefile("${path.module}/scripts/vmdiagnostics.json", { 
    storage_account_name       = data.azurerm_storage_account.diagnostics.name, 
    virtual_machine_id         = azurerm_windows_virtual_machine.vm.id, 
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
                                  null_resource.start_vm,
                                  azurerm_virtual_machine_extension.azure_monitor,
                                # azurerm_firewall_network_rule_collection.*
                                 ]
}
resource azurerm_virtual_machine_extension vm_dependency_monitor {
  name                         = "DAExtension"
  virtual_machine_id           = azurerm_windows_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                         = "DependencyAgentWindows"
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

  count                        = var.dependency_monitor && local.log_analytics_workspace_name != null? 1 : 0
  tags                         = var.tags
  depends_on                   = [
                                  null_resource.start_vm,
                                  azurerm_virtual_machine_extension.azure_monitor
                                 ] 
}
resource azurerm_virtual_machine_extension vm_watcher {
  name                         = "AzureNetworkWatcherExtension"
  virtual_machine_id           = azurerm_windows_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.NetworkWatcher"
  type                         = "NetworkWatcherAgentWindows"
  type_handler_version         = "1.4"
  auto_upgrade_minor_version   = true

  count                        = var.network_watcher ? 1 : 0
  tags                         = var.tags
  depends_on                   = [
                                  null_resource.start_vm,
                                  azurerm_virtual_machine_extension.azure_monitor
                                 ]
}

# Delay DiskEncryption to mitigate race condition
resource null_resource vm_sleep {
  # Always run this
  triggers                     = {
    vm                         = azurerm_windows_virtual_machine.vm.id
  }

  provisioner "local-exec" {
    command                    = "Start-Sleep 300"
    interpreter                = ["pwsh", "-nop", "-Command"]
  }

  count                        = var.disk_encryption ? 1 : 0
  depends_on                   = [azurerm_windows_virtual_machine.vm]
}
# Does not work with AutoLogon
# use server side encryption with azurerm_disk_encryption_set instead
resource azurerm_virtual_machine_extension vm_disk_encryption {
  name                         = "DiskEncryption"
  virtual_machine_id           = azurerm_windows_virtual_machine.vm.id
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
                                # azurerm_firewall_application_rule_collection.*,
                                  null_resource.start_vm,
                                  null_resource.vm_sleep
                                  ]
}

resource azurerm_dev_test_global_vm_shutdown_schedule auto_shutdown {
  virtual_machine_id           = azurerm_windows_virtual_machine.vm.id
  location                     = azurerm_windows_virtual_machine.vm.location
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
  name                         = "${azurerm_windows_virtual_machine.vm.name}-diagnostics"
  target_resource_id           = azurerm_windows_virtual_machine.vm.id
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
                                  azurerm_virtual_machine_extension.vm_bginfo,
                                  azurerm_virtual_machine_extension.vm_dependency_monitor,
                                  azurerm_virtual_machine_extension.vm_diagnostics,
                                  azurerm_virtual_machine_extension.vm_disk_encryption,
                                  azurerm_virtual_machine_extension.log_analytics,
                                  azurerm_virtual_machine_extension.azure_monitor,
                                  azurerm_virtual_machine_extension.vm_watcher
  ]
}

resource local_file pprivate_rdp_file {
  content                      = templatefile("${path.module}/rdp.tpl",
  {
    host                       = azurerm_network_interface.nic.private_ip_address
    username                   = var.admin_username
  })
  filename                     = "${path.root}/../data/${terraform.workspace}/${local.private_fqdn}.rdp"
}
resource local_file public_rdp_file {
  content                      = templatefile("${path.module}/rdp.tpl",
  {
    host                       = azurerm_public_ip.pip.ip_address
    username                   = var.admin_username
  })
  filename                     = "${path.root}/../data/${terraform.workspace}/${local.public_fqdn}.rdp"
}