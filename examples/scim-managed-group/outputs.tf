output "group_id" {
  description = "The Temporal Cloud identifier of the SCIM-provisioned group"
  value       = module.group_access.group_id
}

output "scim_group_name" {
  description = "The group's name, as the identity provider set it"
  value       = data.temporalcloud_scim_group.this.name
}

output "group_account_access" {
  description = "The group's role on the account"
  value       = module.group_access.group_account_access
}

output "group_namespace_accesses" {
  description = "The group's complete namespace access map"
  value       = module.group_access.group_namespace_accesses
}
