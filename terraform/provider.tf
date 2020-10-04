# Microsoft Azure Resource Manager Provider
provider "azurerm" {
    version = "~> 2.19"
    features {
        virtual_machine {
            # Don't do this in production
            delete_os_disk_on_deletion = true
        }
    }
}

provider "external" {
    version = "~> 1.2.0"
}

provider "http" {
    version = "~> 1.2.0"
}

provider "null" {
    version = "~> 2.1.2"
}

provider "random" {
    version = "~> 2.3.0"
}

provider "time" {
    version = "~> 0.5.0"
}
