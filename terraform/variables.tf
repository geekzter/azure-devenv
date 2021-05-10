
variable admin_ip_ranges {
  default                      = []
}
variable admin_object_id {
  default                      = null
}
variable admin_username {
  default                      = "dev"
}

variable address_space {
  default                      = "10.16.0.0/12"
}

variable deploy_bastion {
  type                         = bool
  default                      = true
}
variable deploy_vpn {
  type                         = bool
  default                      = false
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
variable enable_disk_encryption {
  type                         = bool
  default                      = false
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
  type                         = bool
  default                      = true
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
variable linux_shutdown_time {
  default                      = "2300"
  description                  = "Time the VM will be stopped daily. Setting this to null or an empty string disables auto shutdown. Note shutting down the Linux VM will also disable DNS forwarding for VPN connections."
}
variable linux_vm_size {
  default                      = "Standard_B2s"
}

variable locations {
  type                         = list
  default                      = ["westeurope"]
}

variable public_access_enabled {
  type                         = bool
  default                      = true
}

variable resource_suffix {
  description                  = "The suffix to put at the of resource names created"
  default                      = "" # Empty string triggers a random suffix
}
variable run_id {
  description                  = "The ID that identifies the pipeline / workflow that invoked Terraform"
  default                      = ""
}

variable script_wrapper_check {
  description                  = "Set to true in a .auto.tfvars file to force Terraform to check whether it's run from deploy.ps1"
  type                         = bool
  default                      = false
}

variable ssh_private_key {
  default                      = "~/.ssh/id_rsa"
}

variable ssh_public_key {
  default                      = "~/.ssh/id_rsa.pub"
}

variable timezone {
  default                      = "W. Europe Standard Time"
}

variable vpn_range {
  default                      = "192.168.0.0/24"
}

variable windows_accelerated_networking {
  type                         = bool
  default                      = false
}
variable windows_sku {
  default                      = "20h2-ent-g2"
}
variable windows_os_version {
  default                      = "latest"
}
variable windows_shutdown_time {
  default                      = "2300"
  description                  = "Time the VM will be stopped daily. Setting this to null or an empty string disables auto shutdown."
}
variable windows_vm_size {
  default                      = "Standard_B2ms"
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