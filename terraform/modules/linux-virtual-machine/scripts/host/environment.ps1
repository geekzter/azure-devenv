#!/usr/bin/env pwsh

$env:ASPNETCORE_ENVIRONMENT="Development"


# Terraform environment variables
$env:TF_VAR_backend_resource_group="${tf_backend_resource_group}"
$env:TF_VAR_backend_storage_account="${tf_backend_storage_account}"
$env:TF_VAR_backend_storage_container="${tf_backend_storage_container}"

#$env:ARM_PROVIDER_ENHANCED_VALIDATION="false"
#$env:ARM_PROVIDER_STRICT="false"
$env:ARM_SUBSCRIPTION_ID="${arm_subscription_id}"
$env:ARM_TENANT_ID="${arm_tenant_id}"
$loginError = $(az account show -o none 2>&1)
if (!$loginError) {
    $env:ARM_ACCESS_KEY=$(az storage account keys list -n $env:TF_VAR_backend_storage_account -g $env:TF_VAR_backend_resource_group --subscription ${arm_subscription_id} --query "[0].value" -o tsv)
}
