provider "temporalcloud" {
  # Reads TEMPORAL_CLOUD_API_KEY from the environment.
}

################################################################################
# Local regression coverage
#
# The examples/ directories source the PUBLISHED module so they are copy-pasteable
# for consumers. That means they validate the last release, not the code in this
# repo — a renamed or removed variable would slip through CI unnoticed.
#
# This directory closes that gap: it sources the module by relative path and
# passes EVERY input, so `terraform validate` fails here the moment the variable
# surface changes incompatibly. CI picks it up automatically because it contains a
# versions.tf with required_version.
#
# When you add a variable to the root module, add it here in the same PR. Adding
# it to examples/ has to wait until the next release publishes it.
################################################################################

# Every input the module accepts.
module "all_inputs" {
  source = "../../"

  create_group = true
  name         = "yulei-tflocal-test"
  group_id     = ""

  timeouts = {
    create = "10m"
    delete = "10m"
  }

  create_group_access = true
  account_access      = "developer"

  account_access_custom_roles = ["role-id-placeholder"]

  namespace_accesses = [
    {
      namespace_id = "yulei-tflocal-test.a1b2c3"
      permission   = "write"
    },
  ]

  create_group_members = true
  users                = ["user-id-placeholder"]

  members_timeouts = {
    create = "10m"
    delete = "10m"
  }
}

# The create flag off: proves the module produces no resources and that every
# output still evaluates via its try() fallback.
#
# `name` has no default because the provider requires it, so it is passed empty
# rather than omitted. No group is created, so the empty name goes nowhere.
module "disabled" {
  source = "../../"

  create_group = false
  name         = ""
}

# Minimum viable call: a group and nothing else.
module "minimal" {
  source = "../../"

  name = "yulei-tflocal-minimal"
}

# Access and membership attached to a group this module did not create, which is
# how a SCIM-provisioned group is managed.
module "existing_group" {
  source = "../../"

  # The adopted group keeps its own name, so `name` is empty — passed only
  # because Terraform requires a value for it.
  create_group = false
  name         = ""
  group_id     = "group-id-placeholder"

  create_group_access = true
  account_access      = "none"

  namespace_accesses = [
    {
      namespace_id = "yulei-tflocal-test.a1b2c3"
      permission   = "read"
    },
  ]
}

# The wrapper, exercised through the local path as well.
module "wrapper" {
  source = "../../wrappers"

  defaults = {
    create_group_access = true
    account_access      = "read"
  }

  items = {
    platform = { name = "yulei-tflocal-platform", account_access = "developer" }
    support  = { name = "yulei-tflocal-support" }
  }
}
