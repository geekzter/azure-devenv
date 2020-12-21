terraform {
  required_providers {
    azurerm                    = "~> 2.41"
    cloudinit                  = "~> 2.1.0"
    external                   = "~> 2.0.0"
    http                       = "~> 2.0.0"
    local                      = "~> 2.0.0"
    null                       = "~> 2.1"
    random                     = "~> 2.3"
    time                       = "~> 0.6"
    tls                        = "~> 2.2"
  }
  required_version             = "~> 0.13"
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
