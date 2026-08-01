module "wrapper" {
  source = "../"

  for_each = var.items

  account_access              = try(each.value.account_access, var.defaults.account_access, "")
  account_access_custom_roles = try(each.value.account_access_custom_roles, var.defaults.account_access_custom_roles, null)
  create_group                = try(each.value.create_group, var.defaults.create_group, true)
  create_group_access         = try(each.value.create_group_access, var.defaults.create_group_access, false)
  create_group_members        = try(each.value.create_group_members, var.defaults.create_group_members, false)
  group_id                    = try(each.value.group_id, var.defaults.group_id, "")
  members_timeouts            = try(each.value.members_timeouts, var.defaults.members_timeouts, {})
  name                        = try(each.value.name, var.defaults.name, "")
  namespace_accesses          = try(each.value.namespace_accesses, var.defaults.namespace_accesses, null)
  timeouts                    = try(each.value.timeouts, var.defaults.timeouts, {})
  users                       = try(each.value.users, var.defaults.users, [])
}
