locals {
  create_group = var.create_group

  # The group the access and membership resources attach to: the one this module
  # creates, or an existing group supplied through `group_id`.
  group_id = local.create_group ? try(temporalcloud_group.this[0].id, "") : var.group_id

  # Gated on `var.group_id` rather than `local.group_id`, which is unknown until
  # apply when this module creates the group. A `count` cannot depend on an
  # unknown value.
  has_group = local.create_group || var.group_id != ""

  create_group_access = var.create_group_access && local.has_group

  # `users` is required by the resource, so an empty list means no membership
  # resource rather than a group with no members.
  create_group_members = var.create_group_members && local.has_group && length(var.users) > 0
}

################################################################################
# Group
#
# `timeouts` is the only true block in this provider, hence the dynamic block.
################################################################################

resource "temporalcloud_group" "this" {
  count = local.create_group ? 1 : 0

  name = var.name

  dynamic "timeouts" {
    for_each = length([for v in var.timeouts : v if v != null]) > 0 ? [var.timeouts] : []

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
    }
  }
}

################################################################################
# Access
#
# Managed here rather than in the namespace module: this resource is keyed by the
# group and owns that group's entire access map, account-level role included.
# `namespace_accesses` is a nested attribute, not a block, so it is assigned
# straight from its variable and a null value omits it.
################################################################################

resource "temporalcloud_group_access" "this" {
  count = local.create_group_access ? 1 : 0

  # Not a Terraform resource address: the provider requires `id` as an input here
  # and expects the ID of the group the access applies to.
  id = local.group_id

  account_access              = var.account_access
  account_access_custom_roles = var.account_access_custom_roles
  namespace_accesses          = var.namespace_accesses
}

################################################################################
# Members
#
# A single resource owns the group's whole membership, so this takes `count`
# rather than `for_each` over individual users.
################################################################################

resource "temporalcloud_group_members" "this" {
  count = local.create_group_members ? 1 : 0

  group_id = local.group_id
  users    = var.users

  dynamic "timeouts" {
    for_each = length([for v in var.members_timeouts : v if v != null]) > 0 ? [var.members_timeouts] : []

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
    }
  }
}
