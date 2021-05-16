resource azurerm_storage_account diagnostics {
  name                         = "${lower(replace(azurerm_resource_group.vm_resource_group.name,"-",""))}${local.suffix}diag"
  location                     = azurerm_resource_group.vm_resource_group.location
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  account_kind                 = "StorageV2"
  account_tier                 = "Standard"
  account_replication_type     = "LRS"
  allow_blob_public_access     = true
  blob_properties {
    delete_retention_policy {
      days                     = 365
    }
  }
  enable_https_traffic_only    = true

  tags                         = azurerm_resource_group.vm_resource_group.tags
}

resource azurerm_log_analytics_workspace monitor {
  name                         = "${azurerm_resource_group.vm_resource_group.name}-loganalytics"
  location                     = azurerm_resource_group.vm_resource_group.location
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  sku                          = "PerGB2018"
  retention_in_days            = 30

  tags                         = azurerm_resource_group.vm_resource_group.tags
}
resource azurerm_monitor_diagnostic_setting monitor {
  name                         = "${azurerm_log_analytics_workspace.monitor.name}-diag"
  target_resource_id           = azurerm_log_analytics_workspace.monitor.id
  storage_account_id           = azurerm_storage_account.diagnostics.id

  log {
    category                   = "Audit"
    enabled                    = true

    retention_policy {
      enabled                  = false
    }
  }
  metric {
    category                   = "AllMetrics"

    retention_policy {
      enabled                  = false
    }
  }
}
resource azurerm_log_analytics_solution solution {
  solution_name                = each.value
  location                     = azurerm_resource_group.vm_resource_group.location
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  workspace_resource_id        = azurerm_log_analytics_workspace.monitor.id
  workspace_name               = azurerm_log_analytics_workspace.monitor.name

  plan {
    publisher                  = "Microsoft"
    product                    = "OMSGallery/${each.value}"
  }

  for_each                     = toset([
    "ServiceMap",
    "Updates",
    "VMInsights",
  ])
} 
resource azurerm_log_analytics_solution security_center {
  solution_name                = each.value
  location                     = azurerm_resource_group.vm_resource_group.location
  resource_group_name          = azurerm_resource_group.vm_resource_group.name
  workspace_resource_id        = azurerm_log_analytics_workspace.monitor.id
  workspace_name               = azurerm_log_analytics_workspace.monitor.name

  plan {
    publisher                  = "Microsoft"
    product                    = "OMSGallery/${each.value}"
  }

  for_each                     = var.enable_security_center ? toset([
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
  workspace_id                 = azurerm_log_analytics_workspace.monitor.id
  read_access_id               = azurerm_automation_account.automation.id

  tags                         = azurerm_resource_group.vm_resource_group.tags
}

locals {
  update_time                  = timeadd("${formatdate("YYYY-MM-DD",timestamp())}T${var.shutdown_time}:00+00:00","-2h30m")
}

resource azurerm_resource_group_template_deployment linux_updates {
  name                         = "${azurerm_resource_group.vm_resource_group.name}-linux-updates"
  resource_group_name          = azurerm_automation_account.automation.resource_group_name
  deployment_mode              = "Incremental"
  parameters_content           = jsonencode({
    "automationAccountName"    = {
      value                    = azurerm_automation_account.automation.name
    }
    "interval"                 = {
      value                    = 1
    }
    "operatingSystem"          = {
      value                    = "Linux"
    }
    "scheduleName"             = {
      value                    = "${azurerm_resource_group.vm_resource_group.name}-linux-update-schedule"
    }
    "scope"                    = {
      value                    = [azurerm_resource_group.vm_resource_group.id]
    }
    "startTime"                = {
      value                    = local.update_time
    }
    "timeZone"                 = {
      value                    = var.timezone
    }
  })
  template_content             = file("${path.module}/../arm/update-management.json")

  tags                         = azurerm_resource_group.vm_resource_group.tags
  depends_on                   = [azurerm_log_analytics_linked_service.automation]
}
# "Critical, Security, UpdateRollup, ServicePack, Definition, Updates"
# resource azurerm_resource_group_template_deployment windows_updates {
#   name                         = "${azurerm_resource_group.vm_resource_group.name}-windows-updates"
#   resource_group_name          = azurerm_automation_account.automation.resource_group_name
#   deployment_mode              = "Incremental"
#   parameters_content           = jsonencode({
#     "automationAccountName"    = {
#       value                    = azurerm_automation_account.automation.name
#     }
#     "scheduleName"             = {
#       value                    = "${azurerm_resource_group.vm_resource_group.name}-windows-update-schedule"
#     }
#     "interval"                 = {
#       value                    = 1
#     }
#     "operatingSystem"          = {
#       value                    = "Windows"
#     }
#     "resourceGroupId"          = {
#       value                    = azurerm_resource_group.vm_resource_group.id
#     }
#     "startTime"                = {
#       value                    = local.update_time
#     }
#     "timeZone"                 = {
#       value                    = var.timezone
#     }
#   })
#   template_content             = file("${path.module}/../arm/update-management.json")

#   tags                         = azurerm_resource_group.vm_resource_group.tags
#   depends_on                   = [azurerm_log_analytics_linked_service.automation]
# }