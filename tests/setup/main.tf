# Generates a unique group name per test run.
#
# Temporal Cloud group names must be unique within an account, so a fixed name
# would make a second run — or a concurrent one — fail on a name already in use,
# and would collide with any group a human left behind after a failed run.
#
# Deliberately contacts nothing. This fixture is what the core lifecycle test
# depends on, and a failed `run` block makes every later one *skip*, so anything
# that could fail on an account quota or entitlement belongs in
# `tests/setup-namespace/` instead.
resource "random_pet" "this" {
  length    = 2
  separator = "-"
}
