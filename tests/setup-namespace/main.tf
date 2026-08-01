# A throwaway namespace for the namespace_accesses test.
#
# Separate from `tests/setup/` on purpose. This fixture creates a real namespace,
# which can fail on an account's region entitlements or namespace quota. A failed
# `run` block makes every later block *skip* rather than fail, so putting this in
# the shared fixture would let an unrelated quota problem silently skip the core
# group lifecycle coverage.

resource "random_pet" "this" {
  length    = 2
  separator = "-"
}

# Regions this account is entitled to use.
#
# Not hardcoded: the regions an account may use are a subset of the published
# list, so a fixed ID makes the suite account-specific and can fail with
# "is not a valid Temporal Cloud region".
data "temporalcloud_regions" "available" {}

locals {
  # Sorted so repeat runs pick the same region and results stay comparable.
  region_ids = sort([for r in data.temporalcloud_regions.available.regions : r.id])
}

resource "temporalcloud_namespace" "this" {
  name           = "yulei-tftest-grp-${random_pet.this.id}"
  regions        = [local.region_ids[0]]
  retention_days = 1
  api_key_auth   = true
}
