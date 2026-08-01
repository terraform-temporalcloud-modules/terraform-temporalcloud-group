// Verifies create_group = false against a real provider.
//
// Separate file so it gets its own state and cannot interfere with the group
// created in group.tftest.hcl. Creates no resources, so it is cheap — but it
// still configures the provider, which is why it needs TEMPORAL_CLOUD_API_KEY.

provider "temporalcloud" {}

run "creates_nothing" {
  variables {
    create_group = false

    // Supplied because `name` has no default — the provider marks it required on
    // temporalcloud_group. No group is created here, so the empty name never
    // reaches the API.
    name = ""

    // Both feature gates on, with no group to attach to. Nothing must be created
    // and nothing must error: the resources are gated on a group existing, not
    // just on their own flag.
    create_group_access  = true
    account_access       = "read"
    create_group_members = true
    users                = ["some-user-id"]
  }

  // Every output is count-gated behind try(); these assertions prove the
  // fallbacks evaluate rather than erroring when the module is switched off.
  assert {
    condition     = output.group_id == ""
    error_message = "group_id should fall back to empty when create_group = false and no group_id was supplied"
  }

  assert {
    condition     = output.group_name == ""
    error_message = "group_name should fall back to empty when create_group = false"
  }

  assert {
    condition     = output.group_state == ""
    error_message = "group_state should fall back to empty when create_group = false"
  }

  assert {
    condition     = output.group_account_access == ""
    error_message = "group_account_access should fall back to empty with no group to attach to"
  }

  assert {
    // length(), not == tolist([]): the output is an empty tuple, which never
    // compares equal to a list.
    condition     = length(output.group_account_access_custom_roles) == 0
    error_message = "group_account_access_custom_roles should fall back to an empty set"
  }

  assert {
    condition     = length(output.group_namespace_accesses) == 0
    error_message = "group_namespace_accesses should fall back to an empty set"
  }

  assert {
    condition     = length(output.group_members) == 0
    error_message = "group_members should fall back to an empty set"
  }
}
