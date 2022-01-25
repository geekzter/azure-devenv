locals {
  diagnostics_storage_name     = element(split("/",var.diagnostics_storage_id),length(split("/",var.diagnostics_storage_id))-1)
  diagnostics_storage_rg       = element(split("/",var.diagnostics_storage_id),length(split("/",var.diagnostics_storage_id))-5)
  dns_zone_name                = var.dns_zone_id != null ? element(split("/",var.dns_zone_id),length(split("/",var.dns_zone_id))-1) : null
  dns_zone_rg                  = var.dns_zone_id != null ? element(split("/",var.dns_zone_id),length(split("/",var.dns_zone_id))-5) : null
  key_vault_name               = element(split("/",var.key_vault_id),length(split("/",var.key_vault_id))-1)
  key_vault_rg                 = element(split("/",var.key_vault_id),length(split("/",var.key_vault_id))-5)
  log_analytics_workspace_name = element(split("/",var.log_analytics_workspace_id),length(split("/",var.log_analytics_workspace_id))-1)
  log_analytics_workspace_rg   = element(split("/",var.log_analytics_workspace_id),length(split("/",var.log_analytics_workspace_id))-5)
  virtual_network_id           = join("/",slice(split("/",var.vm_subnet_id),0,length(split("/",var.vm_subnet_id))-2))

  private_fqdn                 = replace(azurerm_private_dns_a_record.computer_name.fqdn,"/\\W*$/","")
  public_fqdn                  = local.dns_zone_rg != null ? replace(azurerm_dns_a_record.fqdn.0.fqdn,"/\\W*$/","") : azurerm_public_ip.pip.fqdn

  vm_name                      = "${data.azurerm_resource_group.vm_resource_group.name}-${var.location}-${var.moniker}"
  computer_name                = substr(lower(replace("windows${var.location}","/a|e|i|o|u|y/","")),0,15)

  environment_variables        = merge(
    {
      arm_subscription_id      = data.azurerm_client_config.current.subscription_id
      arm_tenant_id            = data.azurerm_client_config.current.tenant_id
      # Defaults, will be overriden by variables passed into map merge
      tf_state_resource_group = ""
      tf_state_storage_account= ""
      tf_state_storage_container= ""
    },
    var.environment_variables
  )
}

data azurerm_client_config current {}

data azurerm_resource_group vm_resource_group {
  name                         = var.resource_group_name
}

data azurerm_storage_account diagnostics {
  name                         = local.diagnostics_storage_name
  resource_group_name          = local.diagnostics_storage_rg
}
resource time_offset sas_expiry {
  offset_years                 = 1
}
resource time_offset sas_start {
  offset_days                  = -10
}
data azurerm_storage_account_sas diagnostics {
  connection_string            = data.azurerm_storage_account.diagnostics.primary_connection_string
  https_only                   = true

  resource_types {
    service                    = false
    container                  = true
    object                     = true
  }

  services {
    blob                       = true
    queue                      = false
    table                      = true
    file                       = false
  }

  start                        = time_offset.sas_start.rfc3339
  expiry                       = time_offset.sas_expiry.rfc3339  

  permissions {
    read                       = false
    add                        = true
    create                     = true
    write                      = true
    delete                     = false
    list                       = true
    update                     = true
    process                    = false
  }
}


data azurerm_key_vault vault {
  name                         = local.key_vault_name
  resource_group_name          = local.key_vault_rg
}

data azurerm_log_analytics_workspace monitor {
  name                         = local.log_analytics_workspace_name
  resource_group_name          = local.log_analytics_workspace_rg
}

resource time_static vm_update {
  triggers = {
    # Save the time each switch of an VM NIC
    nic_id                     = azurerm_network_interface.nic.id
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
  name                         = "AdminRAS"
  priority                     = 201
  direction                    = "Inbound"
  access                       = var.public_access_enabled ? "Allow" : "Deny"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "3389"
  source_address_prefixes      = var.admin_cidr_ranges
  destination_address_prefix   = "*"
  resource_group_name          = azurerm_network_security_group.nsg.resource_group_name
  network_security_group_name  = azurerm_network_security_group.nsg.name
}

resource azurerm_network_interface_security_group_association nic_nsg {
  network_interface_id         = azurerm_network_interface.nic.id
  network_security_group_id    = azurerm_network_security_group.nsg.id
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
  os_offer                     = var.os_offer
  os_publisher                 = var.os_publisher
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
  enable_automatic_updates     = true

  dynamic "additional_unattend_content" {
    for_each = range(var.prepare_host ? 1 : 0)
    content {
      setting                = "AutoLogon"
      content                = templatefile("${path.module}/scripts/host/AutoLogon.xml", { 
        count                = 99, 
        username             = var.admin_username, 
        password             = var.admin_password
      })
    }
  }

  dynamic "additional_unattend_content" {
    for_each = range(var.prepare_host ? 1 : 0)
    content {
      setting                = "FirstLogonCommands"
      content                = file("${path.module}/scripts/host/FirstLogonCommands.xml")
    }
  }
  
  boot_diagnostics {
    storage_account_uri        = "${data.azurerm_storage_account.diagnostics.primary_blob_endpoint}${data.azurerm_storage_account_sas.diagnostics.sas}"
  }

  custom_data                  = base64encode(templatefile("${path.module}/scripts/host/setup_windows_vm.ps1", merge(
    { 
      bootstrap_branch         = var.bootstrap_branch
      git_email                = var.git_email,
      git_name                 = var.git_name,
      subnet_id                = var.vm_subnet_id,
      virtual_network_has_gateway = var.virtual_network_has_gateway
      virtual_network_id       = local.virtual_network_id
    },
    local.environment_variables
  )))

  identity {
    type                       = "SystemAssigned, UserAssigned"
    identity_ids               = [var.user_assigned_identity_id]
  }

  os_disk {
    caching                    = "ReadWrite"
    storage_account_type       = "Premium_LRS"
  }

  source_image_id              = var.os_image_id

  dynamic "source_image_reference" {
    for_each = range(var.os_image_id == null || var.os_image_id == "" ? 1 : 0) 
    content {
      publisher                = local.os_publisher
      offer                    = local.os_offer
      sku                      = var.os_sku
      version                  = local.os_version
    }
  } 

  tags                         = var.tags
  lifecycle {
    ignore_changes             = [
      additional_unattend_content,
      custom_data,
      source_image_reference.0.version
    ]
  }  
}

resource azurerm_monitor_diagnostic_setting vm {
  name                         = "${azurerm_windows_virtual_machine.vm.name}-diagnostics"
  target_resource_id           = azurerm_windows_virtual_machine.vm.id
  storage_account_id           = var.diagnostics_storage_id

  metric {
    category                   = "AllMetrics"

    retention_policy {
      enabled                  = false
    }
  }
}

# Remove conflicting extensions
resource null_resource prepare_log_analytics {
  triggers                     = {
    vm                         = azurerm_windows_virtual_machine.vm.id
  }

  provisioner local-exec {
    command                    = "${path.root}/../scripts/remove_vm_extension.ps1 -VmName ${azurerm_windows_virtual_machine.vm.name} -ResourceGroupName ${var.resource_group_name} -Publisher Microsoft.EnterpriseCloud.Monitoring -ExtensionType MicrosoftMonitoringAgent -SkipExtensionName OmsAgentForMe"
    interpreter                = ["pwsh","-nop","-command"]
  }

  count                        = var.deploy_log_analytics_extensions ? 1 : 0
}

resource azurerm_virtual_machine_extension log_analytics {
  name                         = "OmsAgentForMe"
  virtual_machine_id           = azurerm_windows_virtual_machine.vm.id
  publisher                    = "Microsoft.EnterpriseCloud.Monitoring"
  type                         = "MicrosoftMonitoringAgent"
  type_handler_version         = "1.0"
  auto_upgrade_minor_version   = true
  settings                     = jsonencode({
    "workspaceId"              = data.azurerm_log_analytics_workspace.monitor.workspace_id
    "azureResourceId"          = azurerm_windows_virtual_machine.vm.id
    "stopOnMultipleConnections"= "true"
  })
  protected_settings           = jsonencode({
    "workspaceKey"             = data.azurerm_log_analytics_workspace.monitor.primary_shared_key
  })

  count                        = var.deploy_log_analytics_extensions ? 1 : 0
  tags                         = var.tags
  depends_on                   = [null_resource.prepare_log_analytics]
}

resource azurerm_virtual_machine_extension azure_monitor {
  name                         = "AzureMonitorWindowsAgent"
  virtual_machine_id           = azurerm_windows_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.Monitor"
  type                         = "AzureMonitorWindowsAgent"
  type_handler_version         = "1.0"
  auto_upgrade_minor_version   = true

  tags                         = var.tags
}

# Delay DiskEncryption to mitigate race condition
resource time_sleep vm_sleep {
  create_duration              = "300s"

  count                        = var.disk_encryption ? 1 : 0
  depends_on                   = [
                                  azurerm_virtual_machine_extension.log_analytics,
  ]
}

resource azurerm_virtual_machine_extension disk_encryption {
  name                         = "DiskEncryption"
  virtual_machine_id           = azurerm_windows_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.Security"
  type                         = "AzureDiskEncryption"
  type_handler_version         = "2.2"
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
                                  azurerm_virtual_machine_extension.azure_monitor,
                                  azurerm_virtual_machine_extension.log_analytics,
                                  time_sleep.vm_sleep
                                  ]
}

resource azurerm_virtual_machine_extension aad_login {
  name                         = "AADLoginForWindows"
  virtual_machine_id           = azurerm_windows_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.ActiveDirectory"
  type                         = "AADLoginForWindows"
  type_handler_version         = "1.0"
  auto_upgrade_minor_version   = true

  count                        = var.aad_login ? 1 : 0
  tags                         = var.tags
  depends_on                   = [azurerm_virtual_machine_extension.disk_encryption]
} 

resource azurerm_virtual_machine_extension bginfo {
  name                         = "BGInfo"
  virtual_machine_id           = azurerm_windows_virtual_machine.vm.id
  publisher                    = "Microsoft.Compute"
  type                         = "BGInfo"
  type_handler_version         = "2.1"
  auto_upgrade_minor_version   = true

  count                        = var.bg_info ? 1 : 0
  tags                         = var.tags
  depends_on                   = [azurerm_virtual_machine_extension.disk_encryption]
}

resource azurerm_virtual_machine_extension diagnostics {
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
  protected_settings           = jsonencode({
    "storageAccountName"       = data.azurerm_storage_account.diagnostics.name
    "storageAccountKey"        = data.azurerm_storage_account.diagnostics.primary_access_key
    "storageAccountEndPoint"   = "https://core.windows.net"
  })

  count                        = var.enable_vm_diagnostics ? 1 : 0
  tags                         = var.tags
  depends_on                   = [azurerm_virtual_machine_extension.disk_encryption]
}
resource azurerm_virtual_machine_extension dependency_monitor {
  name                         = "DAExtension"
  virtual_machine_id           = azurerm_windows_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                         = "DependencyAgentWindows"
  type_handler_version         = "9.5"
  auto_upgrade_minor_version   = true

  count                        = var.dependency_monitor ? 1 : 0
  tags                         = var.tags
  depends_on                   = [
                                  azurerm_virtual_machine_extension.azure_monitor,
                                  azurerm_virtual_machine_extension.log_analytics
                                 ] 
}
resource azurerm_virtual_machine_extension network_watcher {
  name                         = "AzureNetworkWatcherExtension"
  virtual_machine_id           = azurerm_windows_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.NetworkWatcher"
  type                         = "NetworkWatcherAgentWindows"
  type_handler_version         = "1.4"
  auto_upgrade_minor_version   = true

  count                        = var.network_watcher ? 1 : 0
  tags                         = var.tags
  depends_on                   = [azurerm_virtual_machine_extension.disk_encryption]
}
resource azurerm_virtual_machine_extension policy {
  name                         = "AzurePolicyforWindows"
  virtual_machine_id           = azurerm_windows_virtual_machine.vm.id
  publisher                    = "Microsoft.GuestConfiguration"
  type                         = "ConfigurationforWindows"
  type_handler_version         = "1.0"
  auto_upgrade_minor_version   = true

  count                        = var.enable_policy_extension ? 1 : 0
  tags                         = var.tags
  depends_on                   = [azurerm_virtual_machine_extension.disk_encryption]
}

resource azurerm_security_center_server_vulnerability_assessment qualys {
  virtual_machine_id           = azurerm_windows_virtual_machine.vm.id

  depends_on                   = [
                                  azurerm_virtual_machine_extension.aad_login,
                                  azurerm_virtual_machine_extension.azure_monitor,
                                  # azurerm_virtual_machine_extension.bginfo,
                                  azurerm_virtual_machine_extension.dependency_monitor,
                                  azurerm_virtual_machine_extension.diagnostics,
                                  azurerm_virtual_machine_extension.disk_encryption,
                                  azurerm_virtual_machine_extension.log_analytics,
                                  azurerm_virtual_machine_extension.network_watcher,
                                  azurerm_virtual_machine_extension.policy
                                 ]

  count                        = var.enable_security_center ? 1 : 0
}

resource azurerm_dev_test_global_vm_shutdown_schedule auto_shutdown {
  virtual_machine_id           = azurerm_windows_virtual_machine.vm.id
  location                     = azurerm_windows_virtual_machine.vm.location
  enabled                      = true

  daily_recurrence_time        = replace(var.shutdown_time,":","")
  timezone                     = var.timezone

  notification_settings {
    enabled                    = false
  }

  tags                         = var.tags
  count                        = var.shutdown_time != null && var.shutdown_time != "" ? 1 : 0
}

resource local_file private_rdp_file {
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