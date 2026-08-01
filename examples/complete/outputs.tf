output "group_id" {
  description = "The unique identifier of the group"
  value       = module.group.group_id
}

output "group_name" {
  description = "The name of the group"
  value       = module.group.group_name
}

output "group_account_access" {
  description = "The group's role on the account"
  value       = module.group.group_account_access
}

output "group_namespace_accesses" {
  description = "The group's complete namespace access map"
  value       = module.group.group_namespace_accesses
}

output "group_members" {
  description = "IDs of the users that make up the group"
  value       = module.group.group_members
}
