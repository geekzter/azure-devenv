terraform {
  required_providers {
    azuread                    = "~> 2.12"
    azurerm                    = "~> 4.5"
    cloudinit                  = "~> 2.2"
    external                   = "~> 2.1"
    http                       = "~> 2.2"
    local                      = "~> 2.2"
    null                       = "~> 3.1"
    random                     = "~> 3.1"
    time                       = "~> 0.7"
    tls                        = "~> 3.4"
  }
  required_version             = "~> 1.0"
}

# Microsoft Azure Resource Manager Provider
provider azurerm {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    template_deployment {
      # BUG: This uses inconsistent apiVersions which causes destroy to fail
      # Error: removing items provisioned by this Template Deployment: deleting Nested Resource "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/dev-ci-aaaa/providers/Microsoft.Automation/automationAccounts/dev-ci-aaaa-automation/softwareUpdateConfigurations/dev-ci-aaaa-windows-update-schedule": resources.Client#DeleteByID: Failure sending request: StatusCode=0 -- Original Error: Code="NoRegisteredProviderFound" Message="No registered resource provider found for location 'westeurope' and API version '2021-04-01' for type 'automationAccounts/softwareUpdateConfigurations'. The supported api-versions are '2017-05-15-preview, 2018-01-15, 2018-06-30, 2019-06-01, 2020-01-13-preview'. The supported locations are 'japaneast, eastus2, westeurope, southafricanorth, ukwest, switzerlandnorth, brazilsoutheast, norwayeast, germanywestcentral, uaenorth, switzerlandwest, japanwest, uaecentral, australiacentral2, southindia, francesouth, norwaywest, southeastasia, southcentralus, northcentralus, eastasia, centralus, westus, australiacentral, australiaeast, koreacentral, eastus, westus2, brazilsouth, uksouth, westcentralus, northeurope, canadacentral, australiasoutheast, centralindia, francecentral'."
      # Hence set this to false is resources will then get destroyed properly
      delete_nested_items_during_deletion = false
    }
    virtual_machine {
      # Don't do this in production
      delete_os_disk_on_deletion = true
    }
  }

  storage_use_azuread          = true
  
  subscription_id              = var.subscription_id != null && var.subscription_id != "" ? var.subscription_id : data.azurerm_subscription.default.subscription_id
  tenant_id                    = var.tenant_id != null && var.tenant_id != "" ? var.tenant_id : data.azurerm_subscription.default.tenant_id
}

provider azurerm {
  alias                        = "default"
  features {}
}
data azurerm_subscription default {
  provider                     = azurerm.default
}
