variable "create_group" {
  description = "Controls if the group should be created. Set to `false` and supply `group_id` to manage the access and membership of a group that already exists, such as one provisioned by SCIM"
  type        = bool
  default     = true
}

################################################################################
# Group
################################################################################

variable "name" {
  description = "The name of the group. Required unless `create_group` is `false`"
  type        = string
  default     = ""
}

variable "group_id" {
  description = "The ID of an existing group to attach access and membership to. Used only when `create_group` is `false`, for groups created outside Terraform — a SCIM-provisioned group, for example, whose ID comes from the `temporalcloud_scim_group` data source"
  type        = string
  default     = ""
}

variable "timeouts" {
  description = "Create and delete timeouts for the group, as duration strings such as `30s` or `2h45m`"
  type = object({
    create = optional(string)
    delete = optional(string)
  })
  default = {}
}

################################################################################
# Access
#
# Managed here rather than in the namespace module: the underlying resource is
# keyed by the group and owns that group's complete access map.
################################################################################

variable "create_group_access" {
  description = "Controls if the group's access should be managed. Requires either `create_group = true` or `group_id` set to an existing group"
  type        = bool
  default     = false
}

variable "account_access" {
  description = "The group's role on the account: `owner`, `admin`, `developer`, `read` or `none`, matched case-insensitively. Use `none` for a group whose permissions come entirely from `namespace_accesses`. `owner` can only be adopted by import — it cannot be created, updated or deleted without Temporal support. Required unless `create_group_access` is `false`"
  type        = string
  default     = ""

  validation {
    condition     = var.account_access == "" || contains(["owner", "admin", "developer", "read", "none"], lower(var.account_access))
    error_message = "Account access must be one of: owner, admin, developer, read, none (case-insensitive)."
  }
}

variable "account_access_custom_roles" {
  description = "IDs of custom roles granted at account level, in addition to the built-in role in `account_access`. Omit rather than passing an empty set"
  type        = set(string)
  default     = null

  validation {
    condition     = try(length(var.account_access_custom_roles) > 0, true)
    error_message = "Empty custom role sets are not accepted by the provider. Omit the variable instead."
  }
}

variable "namespace_accesses" {
  description = "Per-namespace permissions for the group, as a set of `namespace_id` and `permission` pairs. `permission` is `admin`, `write` or `read`, matched case-insensitively. This replaces the group's entire namespace access map, so it must list every namespace the group can reach. Leave unset for groups whose `account_access` is `owner` or `admin` — those roles already reach every namespace and explicit permissions are rejected. Omit rather than passing an empty set"
  type = set(object({
    namespace_id = string
    permission   = string
  }))
  default = null

  validation {
    condition     = try(length(var.namespace_accesses) > 0, true)
    error_message = "Empty namespace access sets are not accepted by the provider. Omit the variable instead."
  }

  validation {
    condition = try(alltrue([
      for access in var.namespace_accesses :
      contains(["admin", "write", "read"], lower(access.permission))
    ]), true)
    error_message = "Namespace access permission must be one of: admin, write, read (case-insensitive)."
  }
}

################################################################################
# Members
#
# Managed here for the same reason as access. A single resource owns the group's
# complete membership, so there is one of it rather than one per user.
################################################################################

variable "create_group_members" {
  description = "Controls if the group's membership should be managed. Requires either `create_group = true` or `group_id` set to an existing group. Leave `false` for SCIM-provisioned groups, whose membership is owned by the identity provider"
  type        = bool
  default     = false
}

variable "users" {
  description = "IDs of the users that make up the group, as returned by the `temporalcloud_users` data source or the `id` of a `temporalcloud_user` resource. This replaces the group's entire membership, so users added outside Terraform are removed on the next apply. An empty set creates no membership resource"
  type        = set(string)
  default     = []
}

variable "members_timeouts" {
  description = "Create and delete timeouts for the group membership, as duration strings such as `30s` or `2h45m`"
  type = object({
    create = optional(string)
    delete = optional(string)
  })
  default = {}
}
