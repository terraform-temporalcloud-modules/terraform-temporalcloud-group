################################################################################
# Group
#
# Outputs are wrapped in `try()` so they still evaluate to an empty value when
# `create_group = false` leaves no resource to reference.
################################################################################

output "group_id" {
  description = "The unique identifier of the group. Echoes `group_id` when the module manages an existing group rather than creating one"
  value       = try(local.group_id, "")
}

output "group_name" {
  description = "The name of the group. Empty when the module manages a group it did not create"
  value       = try(temporalcloud_group.this[0].name, "")
}

output "group_state" {
  description = "The current state of the group. Empty when the module manages a group it did not create"
  value       = try(temporalcloud_group.this[0].state, "")
}

################################################################################
# Access
################################################################################

output "group_account_access" {
  description = "The group's role on the account"
  value       = try(temporalcloud_group_access.this[0].account_access, "")
}

output "group_account_access_custom_roles" {
  description = "IDs of the custom roles granted to the group at account level"
  value       = try(temporalcloud_group_access.this[0].account_access_custom_roles, [])
}

output "group_namespace_accesses" {
  description = "The group's complete namespace access map, as a set of `namespace_id` and `permission` pairs"
  value       = try(temporalcloud_group_access.this[0].namespace_accesses, [])
}

################################################################################
# Members
################################################################################

output "group_members" {
  description = "IDs of the users that make up the group"
  value       = try(temporalcloud_group_members.this[0].users, [])
}
