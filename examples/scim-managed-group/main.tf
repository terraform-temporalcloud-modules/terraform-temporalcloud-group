provider "temporalcloud" {
  # Reads TEMPORAL_CLOUD_API_KEY from the environment.
}

################################################################################
# A group that already exists, provisioned by SCIM
#
# When SCIM is enabled, the identity provider creates the group in Temporal Cloud
# and keeps its membership in sync. Temporal Cloud assigns both to the
# integration: a SCIM group cannot be created or deleted any other way, and its
# membership is managed through it. Terraform therefore adopts the group by ID and
# leaves its members alone.
#
# The data source resolves the group's Temporal Cloud ID from the ID it carries in
# the identity provider.
################################################################################

data "temporalcloud_scim_group" "this" {
  idp_id = var.idp_group_id
}

################################################################################
# Terraform owns the group's permissions, and nothing else
#
# Roles and namespace permissions are assigned in Temporal Cloud once the group
# has synced, so they are the one part of a SCIM group that has to be set here.
################################################################################

module "group_access" {
  source  = "terraform-temporalcloud-modules/group/temporalcloud"
  version = "~> 1.0"

  # The group exists already: adopt it rather than creating a second one with the
  # same name. `name` is required by the module because the provider requires it
  # when a group *is* created; here it is empty, and the SCIM-provisioned group
  # keeps whatever name the identity provider gave it.
  create_group = false
  name         = ""
  group_id     = data.temporalcloud_scim_group.this.id

  create_group_access = true

  # `none` gives the group no account-wide role, so its reach is exactly the
  # namespaces listed below.
  account_access = "none"

  namespace_accesses = [
    {
      namespace_id = var.namespace_id
      permission   = "write"
    },
  ]

  # Left off deliberately. Membership belongs to the identity provider.
  create_group_members = false
}
