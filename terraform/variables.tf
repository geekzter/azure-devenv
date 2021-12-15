
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
variable deploy_linux {
  type                         = bool
  default                      = true
  description                  = "Disabling this, also disables DNS forwarding"
}
variable deploy_log_analytics_extensions {
  type                         = bool
  default                      = true
  description                  = "Disabling to prevent collisions with agents provisioned through other means e.g. inherited policy"
}
variable deploy_windows {
  type                         = bool
  default                      = true
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
variable enable_security_center {
  type                         = bool
  default                      = false
}
variable enable_update_schedule {
  type                         = bool
  default                      = false
}
variable enable_vm_diagnostics {
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
variable linux_vm_size {
  default                      = "Standard_B2s"
}

variable locations {
  type                         = list
  default                      = ["westeurope"]
}

variable log_analytics_workspace_id {
  description                  = "Specify a pre-existing Log Analytics workspace. The workspace needs to have the Security, SecurityCenterFree, ServiceMap, Updates, VMInsights solutions provisioned"
  default                      = ""
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

variable shutdown_time {
  default                      = "23:59"
  description                  = "Time the VM will be stopped daily. Setting this to null or an empty string disables auto shutdown."
}

variable ssh_private_key {
  default                      = "~/.ssh/id_rsa"
}

variable ssh_public_key {
  default                      = "~/.ssh/id_rsa.pub"
}

variable tags {
  description                  = "A map of the tags to use for the resources that are deployed"
  type                         = map

  default = {
    shutdown                   = "true"
  }  
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
variable windows_offer {
  default                      = "Windows-10"
}
variable windows_os_version {
  default                      = "latest"
}
variable windows_sku {
  default                      = "win10-21h2-pro-g2"
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