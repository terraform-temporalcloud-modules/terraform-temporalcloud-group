# Referencing every output forces Terraform to evaluate each one, so a broken
# output expression fails validation here rather than in a consumer's plan.

output "all_inputs" {
  description = "Every output of the fully configured module instance"
  value = {
    group_id                          = module.all_inputs.group_id
    group_name                        = module.all_inputs.group_name
    group_state                       = module.all_inputs.group_state
    group_account_access              = module.all_inputs.group_account_access
    group_account_access_custom_roles = module.all_inputs.group_account_access_custom_roles
    group_namespace_accesses          = module.all_inputs.group_namespace_accesses
    group_members                     = module.all_inputs.group_members
  }
}

output "disabled" {
  description = "Outputs when create_group is false — every one must fall back rather than error"
  value = {
    group_id                          = module.disabled.group_id
    group_name                        = module.disabled.group_name
    group_state                       = module.disabled.group_state
    group_account_access              = module.disabled.group_account_access
    group_account_access_custom_roles = module.disabled.group_account_access_custom_roles
    group_namespace_accesses          = module.disabled.group_namespace_accesses
    group_members                     = module.disabled.group_members
  }
}

output "minimal" {
  description = "Outputs from the minimum viable module call"
  value       = module.minimal.group_id
}

output "existing_group" {
  description = "Outputs when access is attached to a group the module did not create"
  value = {
    group_id                 = module.existing_group.group_id
    group_account_access     = module.existing_group.group_account_access
    group_namespace_accesses = module.existing_group.group_namespace_accesses
  }
}

output "wrapper" {
  description = "Wrapper outputs, keyed by item name"
  value       = module.wrapper.wrapper
}
