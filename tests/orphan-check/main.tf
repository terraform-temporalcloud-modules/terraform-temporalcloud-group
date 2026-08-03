# Reports test resources still present in the account.
#
# Creates nothing: a data source and outputs only. `terraform test` destroys what
# it creates, but a cancelled or crashed run can leave something behind, and
# nothing else would notice.
#
# Run after the apply tests. Anything reported here is a leftover.
#
# LIMITATION — groups themselves cannot be checked. The provider exposes no
# `temporalcloud_groups` data source, and `temporalcloud_scim_group` resolves only
# a group already known by its identity provider ID, which a Terraform-created
# group does not have. So this covers the throwaway namespaces created by
# `tests/setup-namespace/`, and leftover groups have to be looked for in the
# Temporal Cloud UI. `tests/README.md` says the same thing to whoever reads a
# clean result.

data "temporalcloud_namespaces" "all" {}

locals {
  # The data source returns null, not an empty list, when the account holds no
  # namespaces. Iterating that raises "Iteration over null value" and fails the
  # check on exactly the accounts with nothing to report, so coalesce first.
  orphans = [
    for n in coalesce(data.temporalcloud_namespaces.all.namespaces, []) : n.name
    if startswith(n.name, var.test_resource_prefix)
  ]
}
