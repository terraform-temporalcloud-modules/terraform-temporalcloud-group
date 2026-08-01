provider "temporalcloud" {
  # Reads TEMPORAL_CLOUD_API_KEY from the environment.
}

locals {
  name = "ex-${basename(path.cwd)}"
}

################################################################################
# A namespace for the group to be granted access to
#
# Created here so the example is self-contained. In a real configuration these
# namespace IDs come from wherever your namespaces are already managed.
################################################################################

data "temporalcloud_regions" "available" {}

resource "temporalcloud_namespace" "this" {
  name           = local.name
  regions        = [sort([for r in data.temporalcloud_regions.available.regions : r.id])[0]]
  retention_days = 1
  api_key_auth   = true
}

################################################################################
# Existing users to place in the group
#
# Membership is set by user ID, not by email, so the IDs are looked up from the
# accounts that already exist. Nothing here invites anybody: an email that is not
# already a member of the account simply matches nothing.
################################################################################

data "temporalcloud_users" "all" {}

locals {
  member_ids = [
    for u in data.temporalcloud_users.all.users : u.id
    if contains(var.member_emails, u.email)
  ]
}

################################################################################
# Complete: every input this module supports
################################################################################

module "group" {
  source  = "terraform-temporalcloud-modules/group/temporalcloud"
  version = "~> 2.0"

  name = local.name

  timeouts = {
    create = "10m"
    delete = "10m"
  }

  # Access is folded into this module because the underlying resource is keyed by
  # the group and owns that group's entire access map.
  create_group_access = true

  # `developer` rather than `admin`: owner and admin already reach every
  # namespace, and combining them with explicit namespace_accesses is rejected.
  account_access = "developer"

  namespace_accesses = [
    {
      namespace_id = temporalcloud_namespace.this.id
      permission   = "write"
    },
  ]

  # Membership is a singleton resource that owns the whole member list, so this
  # replaces any members added outside Terraform. With no emails supplied,
  # `member_ids` is empty and no membership resource is created.
  create_group_members = true
  users                = local.member_ids

  members_timeouts = {
    create = "10m"
    delete = "10m"
  }
}
