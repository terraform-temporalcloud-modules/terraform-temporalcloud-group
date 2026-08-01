# Tests

Not usage examples — see [examples/](../examples) for those.

| Path | Runs on | Credentials |
| --- | --- | --- |
| `local/` | every pull request | no |
| `*.tftest.hcl` | on demand, weekly | **yes** |
| `setup/`, `setup-namespace/` | helpers for `*.tftest.hcl` | no / yes |

`local/` passes every module input and references every output, so `terraform
validate` fails there as soon as the variable surface changes.

`*.tftest.hcl` applies against a real Temporal Cloud account, which is the only
way to catch the API rejecting a configuration that type-checks.

| File | Covers |
| --- | --- |
| `group.tftest.hcl` | Create a group; then update it in place to add, change and remove account-level access |
| `namespace_access.tftest.hcl` | `namespace_accesses` against a real namespace, created and torn down by `setup-namespace/` |
| `wrappers.tftest.hcl` | The `wrappers` submodule: two groups from one call, with per-item overrides |
| `disabled.tftest.hcl` | `create_group = false` creates nothing, even with both feature gates on, and every output falls back |

## Why there are two setup fixtures

A failed `run` block makes every later one **skip** rather than fail, so a fixture
that can fail for account-specific reasons must not sit in front of core coverage.

`setup/` generates a unique group name and contacts nothing, so it cannot fail. It
is the fixture the core lifecycle test depends on.

`setup-namespace/` additionally creates a throwaway namespace, which can fail on
region entitlements or a namespace quota. Only `namespace_access.tftest.hcl` uses
it, so such a failure costs that file alone.

## What is not covered on apply

**`users` / `create_group_members`.** Membership is set by user ID, and every ID in
an account belongs to a real person. Creating one means inviting somebody, which
sends a real email and leaves a real account member behind that the suite cannot
reliably remove; borrowing an existing colleague's ID means changing that person's
live access for the duration of a test run. Neither is acceptable in an automated
suite, so it is verified only by `local/`.

To exercise it by hand against a scratch account:

```bash
# Pick an ID belonging to a user you are willing to move in and out of a group.
terraform console
> data.temporalcloud_users.all.users
```

then add a run block passing `create_group_members = true` and that ID, and assert
`length(output.group_members) == 1`. Delete it again rather than committing it.

**`account_access_custom_roles`.** Needs a `temporalcloud_custom_role` to point at,
and a role ID that does not exist is rejected. That resource belongs to a different
module in this family, so the suite has nothing to borrow. Covered by `local/`
only.

**`group_id` against a SCIM group.** The `scim-managed-group` example needs a group
that an identity provider actually provisioned. A test account with no SCIM
integration cannot produce one, and `temporalcloud_scim_group` only resolves groups
that already carry an identity provider ID. `local/` covers the variable surface;
the API behaviour is unverified.

Files run sequentially and each is torn down before the next begins, so only
`wrappers.tftest.hcl` has more than one group alive at a time.

[CONTRIBUTING.md](../CONTRIBUTING.md) explains why the layers are split this way
and which API behaviours they guard against.

## Running the apply tests

```bash
export TEMPORAL_CLOUD_API_KEY="<key for a scratch account>"
terraform init
terraform test -verbose
```

Point them at a scratch account: they create and destroy **real, billable**
resources.

Without a key, every run block is skipped — a cheap way to confirm the test files
parse:

```text
Failure! 0 passed, 0 failed, 11 skipped.
```

## Cleaning up leftovers

`terraform test` destroys what it created, including after a failed assertion, but
a cancelled or crashed run can orphan something. The CI workflow therefore runs
`scripts/check-orphans.sh` afterwards — always, including when the tests fail,
since that is when something is most likely to be left behind.

```bash
scripts/check-orphans.sh
```

**It cannot see groups.** The provider exposes no `temporalcloud_groups` data
source, and `temporalcloud_scim_group` resolves only groups an identity provider
owns, which a Terraform-created group is not. The script therefore checks the
throwaway namespaces and says so explicitly on a clean result, rather than
implying a coverage it does not have. Leftover groups have to be looked for in the
Temporal Cloud UI.

Test resources are prefixed so they are identifiable:

| Prefix | Created by |
| --- | --- |
| `yulei-tftest-grp-<random>` | `*.tftest.hcl` — groups, and the namespace in `setup-namespace/` |
| `yulei-tflocal-*` | `local/`, only if applied by hand — CI never applies it |

Anything matching those prefixes that no live configuration owns can be deleted.

The `examples/` directories are not covered by this prefix; `complete` creates a
group and a namespace both named `ex-complete`. Example code is published to the
Terraform Registry, so it carries no test-specific naming. Check for those
separately if you have applied an example by hand.
