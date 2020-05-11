# Microsoft Azure Resource Manager Provider
provider "azurerm" {
    version = "~> 2.8"
    features {
        virtual_machine {
            # Don't do this in production
            delete_os_disk_on_deletion = true
        }
    }
}
