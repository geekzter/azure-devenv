
variable admin_ip_ranges {
  default                      = []
}
variable admin_object_id {
  default                      = null
}
variable admin_username {
    default                    = "dev"
}
variable deploy_vpn {
    type                       = bool
    default                    = false
}
variable development_resource_group {
  default                      = "Development"
}

variable development_network {
  default                      = "Development-vnet"
}
variable devops_org {
  default                      = null

}
variable devops_pat {
  default                      = null
}
variable dns_zone_id {
  default                      = null
}
variable environment_variables {
  type                         = map
  default = {
    provisioner                = "terraform"
  }
} 
variable git_email {
  default                      = ""
}
variable git_name {
  default                      = ""
}
variable global_vnet_peering {
    type                       = bool
    default                    = true
}
variable linux_bootstrap {
    type                       = bool
    default                    = false
}
variable linux_os_offer {
  default                      = "UbuntuServer"
}
variable linux_os_publisher {
  default                      = "Canonical"
}
variable linux_os_sku {
  default                      = "18.04-LTS"
}
variable linux_os_version {
  default                      = "latest"
}
variable linux_vm_size {
  default                      = "Standard_D2s_v3"
}

variable locations {
  type                         = list
  default                      = ["westeurope"]
}
variable log_analytics_workspace_id {
  default                      = null
}

variable public_access_enabled {
  type                         = bool
  default                      = true
}

variable ssh_private_key {
  default                      = "~/.ssh/id_rsa"
}

variable ssh_public_key {
  default                      = "~/.ssh/id_rsa.pub"
}

variable vpn_range {
  default                      = "192.168.0.0/24"
}

variable windows_sku {
  default                      = "20h2-ent-g2"
}
variable windows_os_version {
  default                      = "latest"
}
variable windows_vm_size {
  default                      = "Standard_D4s_v3"
}
variable vm_domain {
  default                      = "dev.internal"
}
variable vm_subnet {
  default                      = "default"
}

# Certificate data
variable organization {
  default                      = "DevelopersInc"
}