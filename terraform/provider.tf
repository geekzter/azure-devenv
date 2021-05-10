terraform {
  required_providers {
    azurerm                    = "~> 2.56"
    cloudinit                  = "~> 2.2"
    external                   = "~> 2.1"
    http                       = "~> 2.1"
    local                      = "~> 2.1"
    null                       = "~> 3.1"
    random                     = "~> 3.1"
    time                       = "~> 0.7"
    tls                        = "~> 3.1"
  }
  required_version             = ">= 0.14.0"
}

# Microsoft Azure Resource Manager Provider
provider azurerm {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
    virtual_machine {
      # Don't do this in production
      delete_os_disk_on_deletion = true
    }
  }
}
