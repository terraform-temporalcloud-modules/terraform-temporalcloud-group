#!/usr/bin/env bash
#
# Fails if the test suite left resources behind.
#
# `terraform test` destroys what it created, including after a failed assertion,
# but a cancelled or crashed run can orphan something and nothing else would
# notice. Run this after the apply tests.
#
# Covers the throwaway namespaces created by tests/setup-namespace. It CANNOT
# cover groups: the provider exposes no groups data source, and
# temporalcloud_scim_group resolves only groups an identity provider owns. A
# leftover group has to be looked for in the Temporal Cloud UI, under the
# `yulei-tftest-grp-` prefix the suite uses. A clean result here is therefore not
# proof that no group was orphaned.
#
# Requires TEMPORAL_CLOUD_API_KEY. Creates nothing — tests/orphan-check contains a
# data source and outputs only.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)/tests/orphan-check"

terraform init -backend=false -no-color >/dev/null
terraform apply -auto-approve -no-color >/dev/null

count="$(terraform output -raw orphan_count)"

if [ "$count" -eq 0 ]; then
  echo "No leftover test namespaces."
  echo "NOTE: groups are not covered — no data source can enumerate them. Check the"
  echo "      Temporal Cloud UI for groups named yulei-tftest-grp-*."
  exit 0
fi

echo "ERROR: $count test namespace(s) still present after the suite finished:" >&2
terraform output -json orphans | sed 's/[][",]/ /g' | tr -s ' ' '\n' | sed '/^$/d;s/^/  - /' >&2
echo >&2
echo "These were not destroyed. Delete them in the Temporal Cloud UI, or import and" >&2
echo "destroy them. Check for leftover yulei-tftest-grp-* groups at the same time: no data" >&2
echo "source can enumerate groups, so this script cannot report them." >&2
exit 1
