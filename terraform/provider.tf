terraform {
  required_providers {
    azurerm                    = "~> 2.49"
    cloudinit                  = "~> 2.1.0"
    external                   = "~> 2.0.0"
    http                       = "~> 2.0.0"
    local                      = "~> 2.0.0"
    null                       = "~> 3.0"
    random                     = "~> 3.0.0"
    time                       = "~> 0.6"
    tls                        = "~> 3.0.0"
  }
  required_version             = "~> 0.14.0"
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
