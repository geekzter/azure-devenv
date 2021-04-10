#!/usr/bin/env pwsh

$env:ASPNETCORE_ENVIRONMENT="Development"

# Azure context
$env:GEEKZTER_AGENT_SUBNET_ID="${subnet_id}"
$env:GEEKZTER_AGENT_VIRTUAL_NETWORK_ID="${virtual_network_id}"

# Terraform environment variables
$env:TF_STATE_backend_resource_group="${tf_backend_resource_group}"
$env:TF_STATE_backend_storage_account="${tf_backend_storage_account}"
# $env:TF_STATE_backend_storage_container="${tf_backend_storage_container}"
$env:TF_VAR_backend_resource_group="${tf_backend_resource_group}"
$env:TF_VAR_backend_storage_account="${tf_backend_storage_account}"
# $env:TF_VAR_backend_storage_container="${tf_backend_storage_container}"

$env:ARM_SUBSCRIPTION_ID="${arm_subscription_id}"
$env:ARM_TENANT_ID="${arm_tenant_id}"
# $loginError = $(az account show -o none 2>&1)
# if (!$loginError) {
#     $env:ARM_ACCESS_KEY=$(az storage account keys list -n $env:TF_VAR_backend_storage_account -g $env:TF_VAR_backend_resource_group --subscription $env:ARM_SUBSCRIPTION_ID --query "[0].value" -o tsv)
# }
