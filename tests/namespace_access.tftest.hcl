// namespace_accesses, which needs a real namespace to point at.
//
// Isolated from tests/group.tftest.hcl on purpose. Its fixture creates a
// namespace, which can fail on an account's region entitlements or namespace
// quota — and a failed run block makes every later one *skip* rather than fail.
// Keeping it here means such a failure costs this file only, not the core group
// lifecycle coverage.

provider "temporalcloud" {}

run "setup" {
  module {
    source = "./tests/setup-namespace"
  }
}

run "create_group_with_namespace_access" {
  variables {
    name = run.setup.group_name

    create_group_access = true

    // `none` gives the group no account-wide role, so its whole reach is the
    // namespace_accesses set below. The provider documents this value as valid
    // for group access even though it is not for most users.
    account_access = "none"

    namespace_accesses = [
      {
        namespace_id = run.setup.namespace_id
        permission   = "write"
      },
    ]
  }

  assert {
    condition     = output.group_id != ""
    error_message = "group_id is empty, so no group was created"
  }

  assert {
    condition     = output.group_account_access == "none"
    error_message = "account_access 'none' was not accepted for a group, got: ${output.group_account_access}"
  }

  assert {
    // length() and index elementwise: the output comes from try(..., []) so it is
    // a tuple, which never compares equal to a list.
    condition     = length(output.group_namespace_accesses) == 1
    error_message = "expected 1 namespace access, got ${length(output.group_namespace_accesses)}"
  }

  assert {
    condition     = tolist(output.group_namespace_accesses)[0].namespace_id == run.setup.namespace_id
    error_message = "the namespace access did not come back pointing at the test namespace"
  }

  assert {
    condition     = tolist(output.group_namespace_accesses)[0].permission == "write"
    error_message = "the namespace access permission did not round-trip through the API"
  }
}

// The permission is mutable in place, and the set is replaced wholesale rather
// than merged.
run "downgrade_namespace_access" {
  variables {
    name = run.setup.group_name

    create_group_access = true
    account_access      = "none"

    namespace_accesses = [
      {
        namespace_id = run.setup.namespace_id
        permission   = "read"
      },
    ]
  }

  assert {
    condition     = length(output.group_namespace_accesses) == 1
    error_message = "expected the namespace access set to be replaced, not appended to"
  }

  assert {
    condition     = tolist(output.group_namespace_accesses)[0].permission == "read"
    error_message = "the namespace access permission was not updated in place"
  }
}
