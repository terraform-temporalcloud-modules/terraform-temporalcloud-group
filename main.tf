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
# This module is the one that grants access, which is the part SAML and SCIM do
# not cover: SAML handles signing in, SCIM provisions people and their group
# memberships, and roles are assigned to a group afterwards. On an account with
# SCIM, prefer granting access to groups here over granting it to individuals
# through the `user` module.
#
# Where the group comes from decides how to call it. A SCIM-provisioned or
# otherwise pre-existing group is adopted with `create_group = false` plus
# `group_id`, leaving `create_group_members` off so the identity provider remains
# the only writer of membership. Without SCIM, let the module create the group and
# manage membership here as well. Workers and CI use a service account and an API
# key, never a group. README.md sets out the full split.
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
