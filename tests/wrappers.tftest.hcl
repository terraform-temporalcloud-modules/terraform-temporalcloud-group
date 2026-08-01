// The wrappers submodule: several groups from one call, with per-item overrides
// of the shared defaults.
//
// This is the only test that creates more than one group at a time, which is the
// behaviour it exists to verify.

provider "temporalcloud" {}

run "setup" {
  module {
    source = "./tests/setup"
  }
}

run "create_many" {
  module {
    source = "./wrappers"
  }

  variables {
    defaults = {
      create_group_access = true
      account_access      = "read"
    }

    items = {
      platform = {
        name = "${run.setup.group_name}-platform"
        // Overrides the shared default above.
        account_access = "developer"
      }

      support = {
        name = "${run.setup.group_name}-support"
      }
    }
  }

  assert {
    condition     = length(output.wrapper) == 2
    error_message = "expected 2 groups from the wrapper, got ${length(output.wrapper)}"
  }

  assert {
    condition     = output.wrapper["platform"].group_name == "${run.setup.group_name}-platform"
    error_message = "the platform item did not take its own name"
  }

  // Per-item values override the defaults rather than merging with them.
  assert {
    condition     = output.wrapper["platform"].group_account_access == "developer"
    error_message = "the per-item account_access did not override the default"
  }

  // Shared defaults reach every item.
  assert {
    condition     = output.wrapper["support"].group_account_access == "read"
    error_message = "defaults.account_access did not reach the support item"
  }

  assert {
    condition     = output.wrapper["support"].group_id != ""
    error_message = "the support item was not created"
  }
}
