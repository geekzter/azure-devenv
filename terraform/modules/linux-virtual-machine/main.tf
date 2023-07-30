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
  virtual_network_id           = join("/",slice(split("/",var.vm_subnet_id),0,length(split("/",var.vm_subnet_id))-2))

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

  vm_name                      = "${var.resource_group_name}-${var.location}-${var.moniker}"
  computer_name                = substr(lower(replace("linux${var.location}","/a|e|i|o|u|y/","")),0,15)
}

data azurerm_client_config current {}

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
    add                        = true
    create                     = true
    delete                     = false
    filter                     = false
    list                       = true
    process                    = false
    read                       = false
    tag                        = false
    update                     = true
    write                      = true
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

resource random_string pip_domain_name_label {
  length                      = 16
  upper                       = false
  lower                       = true
  numeric                     = false
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
  name                         = "${var.resource_group_name}-${var.location}-linux-nsg"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  tags                         = var.tags
}

resource azurerm_network_security_rule admin_ssh {
  name                         = "AdminRAS"
  priority                     = 201
  direction                    = "Inbound"
  access                       = var.enable_public_access ? "Allow" : "Deny"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "22"
  source_address_prefixes      = var.admin_cidr_ranges
  destination_address_prefixes = [
    azurerm_public_ip.pip.ip_address,
    azurerm_network_interface.nic.ip_configuration.0.private_ip_address
  ]
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

  dynamic "part" {
    for_each = range(var.os_image_id != null && var.os_image_id != "" ? 1 : 0) 
    content {
      content                  = templatefile("${path.root}/../cloudinit/cloud-config-post-generation.yaml",
      {
        user_name              = var.user_name
      })
      content_type             = "text/cloud-config"
      merge_type               = "list(append)+dict(recurse_array)+str()"
    }
  }
  part {
    content                    = templatefile("${path.root}/../cloudinit/cloud-config-orchestration.yaml",
    {
      host_name                = local.computer_name
    })
    content_type               = "text/cloud-config"
    merge_type                 = "list(append)+dict(recurse_array)+str()"
  }
  dynamic "part" {
    for_each = range(var.enable_dns_proxy ? 1 : 0)
    content {
      content                    = templatefile("${path.root}/../cloudinit/cloud-config-dns.yaml",
      {
        domain_suffix            = var.domain
        host_name                = local.computer_name
        nic_domain_suffix        = azurerm_network_interface.nic.internal_domain_name_suffix
        private_ip_address       = azurerm_network_interface.nic.private_ip_address
      })
      content_type             = "text/cloud-config"
      merge_type               = "list(append)+dict(recurse_array)+str()"
    }
  }
  dynamic "part" {
    for_each = range(var.install_tools ? 1 : 0)
    content {
      content                  = file("${path.root}/../cloudinit/cloud-config-tools.yaml")
      content_type             = "text/cloud-config"
      merge_type               = "list(append)+dict(recurse_array)+str()"
    }
  }
  part {
    content                    = templatefile("${path.root}/../cloudinit/cloud-config-user.yaml",merge(
    {
      bootstrap_branch         = var.bootstrap_branch
      bootstrap_switches       = "--skip-packages" # var.install_tools ? "" : "--skip-packages"
      environment_ps1          = base64encode(templatefile("${path.module}/scripts/host/environment.ps1", local.environment_variables))
      setup_linux_vm_ps1       = filebase64("${path.module}/scripts/host/setup_linux_vm.ps1")
      subnet_id                = var.vm_subnet_id
      user_name                = var.user_name
      virtual_network_has_gateway = var.virtual_network_has_gateway
      virtual_network_id       = local.virtual_network_id
    },
    local.environment_variables
    ))
    content_type               = "text/cloud-config"
    merge_type                 = "list(append)+dict(recurse_array)+str()"
  }
  # Azure Log Analytics VM extension fails on https://github.com/actions/virtual-environments
  dynamic "part" {
    for_each = range(var.deploy_azure_monitor_extensions ? 1 : 0)
    content {
      content                  = templatefile("${path.root}/../cloudinit/cloud-config-log-analytics.yaml",
      {
        workspace_id           = data.azurerm_log_analytics_workspace.monitor.workspace_id
        workspace_key          = data.azurerm_log_analytics_workspace.monitor.primary_shared_key
      })
      content_type             = "text/cloud-config"
      merge_type               = "list(append)+dict(recurse_array)+str()"
    }
  }
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
  custom_data                  = var.prepare_host ? base64encode(data.cloudinit_config.user_data.rendered) : null

  admin_ssh_key {
    username                   = var.user_name
    public_key                 = file(var.ssh_public_key)
  }

  boot_diagnostics {
    storage_account_uri        = null # Managed Storage Account
  }
  
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
      publisher                = var.os_publisher
      offer                    = var.os_offer
      sku                      = var.os_sku
      version                  = local.os_version
    }
  } 

  tags                         = var.tags
  depends_on                   = [
    azurerm_private_dns_a_record.computer_name,
    azurerm_network_interface_security_group_association.nic_nsg
  ]
  lifecycle {
    ignore_changes             = [
      # Let bootstrap-os update the host configuration
      custom_data,
      source_image_id,
      source_image_reference.0.version
    ]
  }  
}

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

  depends_on                   = [azurerm_virtual_machine_extension.log_analytics]
}

resource azurerm_virtual_machine_extension cloud_config_status {
  name                         = "CloudConfigStatusScript"
  virtual_machine_id           = azurerm_linux_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.Extensions"
  type                         = "CustomScript"
  type_handler_version         = "2.1"
  auto_upgrade_minor_version   = true
  settings                     = jsonencode({
    "commandToExecute"         = "/usr/bin/cloud-init status --long --wait ; systemctl status cloud-final.service --full --no-pager --wait"
  })
  tags                         = var.tags

  timeouts {
    create                     = "60m"
  }  
}

# Remove conflicting extensions
resource null_resource prepare_log_analytics {
  triggers                     = {
    vm                         = azurerm_linux_virtual_machine.vm.id
  }

  provisioner local-exec {
    command                    = "${path.root}/../scripts/remove_vm_extension.ps1 -VmName ${azurerm_linux_virtual_machine.vm.name} -ResourceGroupName ${var.resource_group_name} -Publisher Microsoft.EnterpriseCloud.Monitoring -ExtensionType OmsAgentForLinux -SkipExtensionName OmsAgentForMe"
    interpreter                = ["pwsh","-nop","-command"]
  }

  count                        = var.deploy_azure_monitor_extensions ? 1 : 0
  depends_on                   = [
                                  azurerm_virtual_machine_extension.cloud_config_status
  ]
}

resource azurerm_virtual_machine_extension log_analytics {
  name                         = "OmsAgentForMe"
  virtual_machine_id           = azurerm_linux_virtual_machine.vm.id
  publisher                    = "Microsoft.EnterpriseCloud.Monitoring"
  type                         = "OmsAgentForLinux"
  type_handler_version         = "1.13"
  auto_upgrade_minor_version   = true
  settings                     = jsonencode({
    "workspaceId"              = data.azurerm_log_analytics_workspace.monitor.workspace_id
  })
  protected_settings           = jsonencode({
    "workspaceKey"             = data.azurerm_log_analytics_workspace.monitor.primary_shared_key
  })

  count                        = var.deploy_azure_monitor_extensions ? 1 : 0
  tags                         = var.tags
  depends_on                   = [
                                  azurerm_virtual_machine_extension.cloud_config_status,
                                  null_resource.prepare_log_analytics
  ]
}

# resource azurerm_virtual_machine_extension azure_monitor {
#   name                         = "AzureMonitorLinuxAgent"
#   virtual_machine_id           = azurerm_linux_virtual_machine.vm.id
#   publisher                    = "Microsoft.Azure.Monitor"
#   type                         = "AzureMonitorLinuxAgent"
#   type_handler_version         = "1.5"
#   auto_upgrade_minor_version   = true

#   count                        = var.deploy_azure_monitor_extensions ? 1 : 0
#   tags                         = var.tags
#   depends_on                   = [azurerm_virtual_machine_extension.log_analytics]
# }

# TODO: Replace with Azure Monitoring Agent
# https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/diagnostics-linux?tabs=azcli#python-requirement
resource azurerm_virtual_machine_extension diagnostics {
  name                         = "LinuxDiagnostic"
  virtual_machine_id           = azurerm_linux_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.Diagnostics"
  type                         = "LinuxDiagnostic"
  type_handler_version         = "3.0"
  auto_upgrade_minor_version   = true

  settings                     = templatefile("${path.module}/scripts/vmdiagnostics.json", { 
    storage_account_name       = data.azurerm_storage_account.diagnostics.name, 
    virtual_machine_id         = azurerm_linux_virtual_machine.vm.id
  })
  protected_settings           = jsonencode({
    storageAccountName         = data.azurerm_storage_account.diagnostics.name
    storageAccountSasToken     = trimprefix(data.azurerm_storage_account_sas.diagnostics.sas,"?")
    storageAccountEndPoint     = "https://core.windows.net"
  })

  count                        = var.enable_vm_diagnostics ? 1 : 0
  tags                         = var.tags
  depends_on                   = [
                                  azurerm_virtual_machine_extension.cloud_config_status,
                                  azurerm_virtual_machine_extension.log_analytics
  ]
}

resource azurerm_virtual_machine_extension aad_login {
  name                         = "AADSSHLoginForLinux"
  virtual_machine_id           = azurerm_linux_virtual_machine.vm.id
  publisher                    = "Microsoft.Azure.ActiveDirectory"
  type                         = "AADSSHLoginForLinux"
  type_handler_version         = "1.0"
  auto_upgrade_minor_version   = true

  tags                         = var.tags
  depends_on                   = [
                                  azurerm_virtual_machine_extension.cloud_config_status,
                                  azurerm_virtual_machine_extension.diagnostics,
                                  azurerm_virtual_machine_extension.log_analytics
  ]
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
  depends_on                   = [
                                  azurerm_virtual_machine_extension.cloud_config_status,
                                  azurerm_virtual_machine_extension.diagnostics,
                                  azurerm_virtual_machine_extension.log_analytics
  ]
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
  depends_on                   = [
                                  azurerm_virtual_machine_extension.cloud_config_status,
                                  azurerm_virtual_machine_extension.diagnostics,
                                  azurerm_virtual_machine_extension.log_analytics
  ]
}
resource azurerm_virtual_machine_extension policy {
  name                         = "AzurePolicyforLinux"
  virtual_machine_id           = azurerm_linux_virtual_machine.vm.id
  publisher                    = "Microsoft.GuestConfiguration"
  type                         = "ConfigurationforLinux"
  type_handler_version         = "1.0"
  auto_upgrade_minor_version   = true

  count                        = var.enable_policy_extension ? 1 : 0
  tags                         = var.tags
  depends_on                   = [
                                  azurerm_virtual_machine_extension.cloud_config_status,
                                  azurerm_virtual_machine_extension.diagnostics,
                                  azurerm_virtual_machine_extension.log_analytics
  ]
}

resource azurerm_security_center_server_vulnerability_assessment_virtual_machine qualys {
  virtual_machine_id           = azurerm_linux_virtual_machine.vm.id

  count                        = var.enable_security_center ? 1 : 0
  depends_on                   = [
                                  azurerm_virtual_machine_extension.aad_login,
                                  azurerm_virtual_machine_extension.dependency_monitor,
                                  azurerm_virtual_machine_extension.diagnostics,
                                  azurerm_virtual_machine_extension.log_analytics,
                                  azurerm_virtual_machine_extension.network_watcher,
                                  azurerm_virtual_machine_extension.policy
  ]
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
                                  azurerm_security_center_server_vulnerability_assessment_virtual_machine.qualys,
                                  azurerm_virtual_machine_extension.aad_login,
                                  # azurerm_virtual_machine_extension.azure_monitor,
                                  azurerm_virtual_machine_extension.diagnostics,
                                  azurerm_virtual_machine_extension.dependency_monitor,
                                  azurerm_virtual_machine_extension.log_analytics,
                                  azurerm_virtual_machine_extension.network_watcher,
                                  azurerm_virtual_machine_extension.policy
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
                                  azurerm_security_center_server_vulnerability_assessment_virtual_machine.qualys,
                                  azurerm_virtual_machine_extension.aad_login,
                                  # azurerm_virtual_machine_extension.azure_monitor,
                                  azurerm_virtual_machine_extension.diagnostics,
                                  azurerm_virtual_machine_extension.dependency_monitor,
                                  azurerm_virtual_machine_extension.log_analytics,
                                  azurerm_virtual_machine_extension.network_watcher,
                                  azurerm_virtual_machine_extension.policy,
                                  time_sleep.vm_sleep
  ]
}

resource azurerm_dev_test_global_vm_shutdown_schedule auto_shutdown {
  virtual_machine_id           = azurerm_linux_virtual_machine.vm.id
  location                     = azurerm_linux_virtual_machine.vm.location
  enabled                      = true

  daily_recurrence_time        = replace(var.shutdown_time,":","")
  timezone                     = var.timezone

  notification_settings {
    enabled                    = false
  }

  tags                         = var.tags
  count                        = var.shutdown_time != null && var.shutdown_time != "" ? 1 : 0
}