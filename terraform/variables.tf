
variable admin_object_id {
  default                      = null
}
variable admin_username {}
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
variable dns_zone_id {}
variable git_email {}
variable git_name {}
variable linux_os_offer {
  default                      = "UbuntuServer"
}
variable linux_os_publisher {
  default                      = "Canonical"
}
variable linux_os_sku {
  default                      = "18.04-LTS"
}
variable linux_pipeline_agent_name {
  # Defaults to VM name if empty string
  default                      = "ubuntu1804-agent"
}
variable linux_pipeline_agent_pool {
  default                      = "Default"
}
variable linux_vm_name_prefix {
  default                      = "ubuntu1804-agent"
}
variable linux_vm_size {
  default                      = "Standard_D2s_v3"
}

variable log_analytics_workspace_id {}

variable ssh_public_key {
  default                      = "~/.ssh/id_rsa.pub"
}
variable windows_os_version {
  default                      = "latest"
}
variable windows_pipeline_agent_name {
  # Defaults to VM name if empty string
  default                      = "windows-agent"
}
variable windows_pipeline_agent_pool {
  default                      = "Default"
}
variable windows_vm_name_prefix {
  default                      = "win"
}
variable windows_vm_size {
  default                      = "Standard_D4s_v3"
}
variable vm_subnet {
  default                      = "default"
}
