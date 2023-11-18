locals {
  log_analytics_workspace_id   = var.log_analytics_workspace_id != "" && var.log_analytics_workspace_id != null ? var.log_analytics_workspace_id : azurerm_log_analytics_workspace.monitor.0.id
  diagnostics_storage_id       = module.region_network[azurerm_resource_group.vm_resource_group.location].diagnostics_storage_id
}

resource azurerm_log_analytics_workspace monitor {
  name                         = "${azurerm_resource_group.vm_resource_group.name}-loganalytics"
  location                     = azurerm_resource_group.vm_resource_group.location
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  sku                          = "PerGB2018"
  retention_in_days            = 30

  count                        = var.log_analytics_workspace_id != "" && var.log_analytics_workspace_id != null ? 0 : 1
  tags                         = azurerm_resource_group.vm_resource_group.tags
}
resource azurerm_monitor_diagnostic_setting monitor {
  name                         = "${azurerm_log_analytics_workspace.monitor.0.name}-diag"
  target_resource_id           = azurerm_log_analytics_workspace.monitor.0.id
  storage_account_id           = local.diagnostics_storage_id

  enabled_log {
    category                   = "Audit"
  }
  metric {
    category                   = "AllMetrics"
  }

  count                        = var.log_analytics_workspace_id != "" && var.log_analytics_workspace_id != null ? 0 : 1
}
resource azurerm_log_analytics_solution solution {
  solution_name                = each.value
  location                     = azurerm_resource_group.vm_resource_group.location
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  workspace_resource_id        = azurerm_log_analytics_workspace.monitor.0.id
  workspace_name               = azurerm_log_analytics_workspace.monitor.0.name

  plan {
    publisher                  = "Microsoft"
    product                    = "OMSGallery/${each.value}"
  }

  tags                         = azurerm_resource_group.vm_resource_group.tags

  for_each                     = var.log_analytics_workspace_id != "" && var.log_analytics_workspace_id != null ? toset([]) : toset([
    "ServiceMap",
    "Updates",
    "VMInsights",
  ])
} 
resource azurerm_log_analytics_solution security_center {
  solution_name                = each.value
  location                     = azurerm_resource_group.vm_resource_group.location
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  workspace_resource_id        = azurerm_log_analytics_workspace.monitor.0.id
  workspace_name               = azurerm_log_analytics_workspace.monitor.0.name

  plan {
    publisher                  = "Microsoft"
    product                    = "OMSGallery/${each.value}"
  }

  tags                         = azurerm_resource_group.vm_resource_group.tags

  for_each                     = (var.log_analytics_workspace_id == "" || var.log_analytics_workspace_id == null) && var.enable_policy_extensions ? toset([
    "Security",
    "SecurityCenterFree"
  ]) : toset([])

  depends_on                    = [azurerm_log_analytics_solution.solution]
} 

resource azurerm_automation_account automation {
  name                         = "${azurerm_resource_group.vm_resource_group.name}-automation"
  location                     = azurerm_resource_group.vm_resource_group.location
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  sku_name                     = "Basic"

  tags                         = azurerm_resource_group.vm_resource_group.tags
}

resource azurerm_log_analytics_linked_service automation {
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  workspace_id                 = local.log_analytics_workspace_id
  read_access_id               = azurerm_automation_account.automation.id
}

locals {
  update_time                  = timeadd("${formatdate("YYYY-MM-DD",timestamp())}T${var.shutdown_time}:00+00:00","-2h30m")
}

resource azurerm_automation_software_update_configuration linux_updates {
  name                         = "${azurerm_resource_group.vm_resource_group.name}-linux-updates"
  automation_account_id        = azurerm_automation_account.automation.id

  schedule {
    description                = "Managed by Terraform"
    frequency                  = "Day"
    interval                   = 1
    start_time                 = local.update_time
    time_zone                  = var.timezone
  }

  linux {
    classifications_included   = [
      "Critical",
      "Security"
    ]
    excluded_packages          = ["apt"]
    reboot                     = "IfRequired"
  }
  virtual_machine_ids          = [for vm in module.linux_vm : vm.vm_id] 

  count                        = var.enable_update_schedule ? 1 : 0
  depends_on                   = [
    azurerm_log_analytics_linked_service.automation,
    module.linux_vm
  ]
}

resource azurerm_automation_software_update_configuration windows_updates {
  name                         = "${azurerm_resource_group.vm_resource_group.name}-windows-updates"
  automation_account_id        = azurerm_automation_account.automation.id

  schedule {
    description                = "Managed by Terraform"
    frequency                  = "Day"
    interval                   = 1
    start_time                 = local.update_time
    time_zone                  = var.timezone
  }

  virtual_machine_ids          = [for vm in module.windows_vm : vm.vm_id] 
  windows {
    classifications_included   = [
      "Critical",
      "Definition",
      "FeaturePack",
      "Security",
      "ServicePack",
      "UpdateRollup",
      "Updates"
    ]
    reboot                     = "IfRequired"
  }

  count                        = var.enable_update_schedule ? 1 : 0
  depends_on                   = [
    azurerm_log_analytics_linked_service.automation,
    module.windows_vm
  ]
}