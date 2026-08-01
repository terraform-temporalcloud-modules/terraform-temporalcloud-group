// Main lifecycle: create a group, then update it in place to add the account-level
// access this module folds in.
//
// Creates ONE group and updates it across run blocks rather than one per case.
// Run blocks share state within a file, so a later block with different variables
// updates the group instead of creating another.
//
// The fixture is tests/setup, which only generates a name. Nothing in this file
// depends on a namespace, a quota or a region entitlement, so a problem with any
// of those cannot make the core coverage skip.
//
// terraform test destroys everything it created when the file finishes, including
// after a failed assertion.

provider "temporalcloud" {
  // Reads TEMPORAL_CLOUD_API_KEY from the environment. The module under test
  // declares no provider block, by design for a published module, so the test
  // supplies one.
}

run "setup" {
  module {
    source = "./tests/setup"
  }
}

run "create_group" {
  variables {
    name = run.setup.group_name

    timeouts = {
      create = "10m"
      delete = "10m"
    }
  }

  assert {
    condition     = output.group_name == run.setup.group_name
    error_message = "group_name output did not echo the requested name"
  }

  assert {
    condition     = output.group_id != ""
    error_message = "group_id is empty, so no group was created"
  }

  assert {
    condition     = output.group_state != ""
    error_message = "group_state is empty; the provider reports it as computed"
  }

  // No access or membership requested yet.
  assert {
    condition     = output.group_account_access == ""
    error_message = "expected no account access before create_group_access was set"
  }

  assert {
    // length(), not == tolist([]): the output comes from try(..., []) so it is a
    // tuple, which never compares equal to a list.
    condition     = length(output.group_namespace_accesses) == 0
    error_message = "expected no namespace accesses before any were requested"
  }

  assert {
    condition     = length(output.group_members) == 0
    error_message = "expected no members before any were requested"
  }
}

// Updates the SAME group, adding the access resource. Account-level only: no
// namespace exists in this file, and granting a role needs none.
run "add_account_access" {
  variables {
    name = run.setup.group_name

    timeouts = {
      create = "10m"
      delete = "10m"
    }

    create_group_access = true
    account_access      = "read"
  }

  assert {
    condition     = output.group_account_access == "read"
    error_message = "account_access did not round-trip through the API, got: ${output.group_account_access}"
  }

  // Adding the child resource must not have replaced the group.
  //
  // Compared against the ID create_group returned, not against the name: `name`
  // is an input to this very run block, so a name assertion is a tautology that
  // holds even if the group was destroyed and recreated under the same name.
  // Only the ID distinguishes an update from a replacement.
  assert {
    condition     = output.group_id == run.create_group.group_id
    error_message = "group was replaced rather than updated in place"
  }

  assert {
    condition     = length(output.group_namespace_accesses) == 0
    error_message = "expected no namespace accesses when none were requested"
  }
}

// The account role is mutable in place. `developer` rather than `admin`, because
// admin implicitly reaches every namespace and behaves differently.
run "change_account_access" {
  variables {
    name = run.setup.group_name

    timeouts = {
      create = "10m"
      delete = "10m"
    }

    create_group_access = true
    account_access      = "developer"
  }

  assert {
    condition     = output.group_account_access == "developer"
    error_message = "account_access was not updated in place, got: ${output.group_account_access}"
  }

  // Changing the role must not have taken the group with it.
  assert {
    condition     = output.group_id == run.create_group.group_id
    error_message = "the group was replaced while its account access changed"
  }
}

// Turning the feature gate off must remove the access resource and leave the
// group itself alone.
run "remove_account_access" {
  variables {
    name = run.setup.group_name

    timeouts = {
      create = "10m"
      delete = "10m"
    }

    create_group_access = false
  }

  assert {
    condition     = output.group_account_access == ""
    error_message = "group_account_access should fall back to empty once the gate is off"
  }

  // The SAME group must survive, not merely some group: a non-empty ID would
  // also be reported by a replacement created in its place.
  assert {
    condition     = output.group_id == run.create_group.group_id
    error_message = "the group itself should survive removing its access, with the same ID"
  }
}
