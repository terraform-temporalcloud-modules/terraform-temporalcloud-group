# Generates a unique group name per test run.
#
# A fresh name per run keeps concurrent runs from touching each other's groups,
# and keeps a leftover from an interrupted run distinguishable from the group the
# current run created — which matters because no data source enumerates groups, so
# leftovers are only ever found by name in the Temporal Cloud UI.
#
# Deliberately contacts nothing. This fixture is what the core lifecycle test
# depends on, and a failed `run` block makes every later one *skip*, so anything
# that could fail on an account quota or entitlement belongs in
# `tests/setup-namespace/` instead.
resource "random_pet" "this" {
  length    = 2
  separator = "-"
}
