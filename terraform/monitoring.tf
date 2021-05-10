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
  name                         = "${azurerm_log_analytics_workspace.monitor.name}-diagnostics"
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
  solution_name                 = each.value
  location                      = azurerm_resource_group.vm_resource_group.location
  resource_group_name           = azurerm_resource_group.vm_resource_group.name
  workspace_resource_id         = azurerm_log_analytics_workspace.monitor.id
  workspace_name                = azurerm_log_analytics_workspace.monitor.name

  plan {
    publisher                   = "Microsoft"
    product                     = "OMSGallery/${each.value}"
  }

  for_each                      = toset([
    "ServiceMap",
    "Updates",
    "VMInsights",
  ])
} 
