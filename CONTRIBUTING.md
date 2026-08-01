# Contributing

## Prerequisites

```bash
brew install pre-commit terraform-docs
brew install terraform-linters/tap/tflint
pre-commit install
```

Local tool versions must match the pins in
[`.github/workflows/pre-commit.yml`](.github/workflows/pre-commit.yml). terraform-docs changed its
markdown table style after v0.20.0, so a mismatch makes CI reject README tables that were generated
correctly on your machine. When you bump one side, bump the other in the same pull request.

## The gate

```bash
pre-commit run -a
```

This is what CI runs: `terraform fmt`, `terraform-docs`, `tflint`, `terraform validate`, plus two local
checks described below. Expect the first run after a change to *modify* files — terraform-docs rewrites
the README tables. Re-run until clean; it should pass twice in a row.

## Why access and membership live in this module

Ownership follows the resource's primary key, not its topic.

`temporalcloud_group_access` is keyed by the **group**, and its `namespace_accesses` attribute is a set
spanning every namespace that group can reach. Putting it in the namespace module would be a
correctness bug rather than a style choice: two namespace module instances referencing the same group
would each rewrite that group's whole access map and clobber each other. It would also force the
namespace module to set an account-level role, which has nothing to do with a namespace.

`temporalcloud_group_members` is keyed by the group too, and the provider documents it as "only use one
per group". Singletons take `count`, never `for_each`.

Neither is a `modules/` submodule. A submodule shares the parent repository's git tag, which forfeits
the independent release cycle every module in this family has.

## Test layers

| Path | Runs on | Credentials | Proves |
| --- | --- | --- | --- |
| `examples/*` | every PR | no | The documented usage still type-checks against this code |
| `tests/local/` | every PR | no | Every input and output is still valid |
| `tests/*.tftest.hcl` | on demand, weekly | **yes** | Temporal Cloud accepts the payloads this module sends |

`terraform validate` is not a test: it never executes anything and never contacts the API. Only the
apply layer can catch the API rejecting a configuration that looks valid.

`terraform plan` is not a usable middle ground, because the provider authenticates when it initialises
and so needs a real key even for a plan that would create nothing.

### Why examples are validated indirectly

`examples/*` source the **published** module so consumers can copy them verbatim from the Terraform
Registry. Validating them as written would check the last release rather than the working tree, which
would mean a module change and its example update could never land in the same pull request.

[`scripts/validate-examples.sh`](scripts/validate-examples.sh) resolves this: it copies each example to
a temporary directory, rewrites the registry source to a path to the repository root, and validates the
copy. Tracked files are never modified. `terraform_validate` excludes `examples/`, and the
`examples-validate` hook covers them instead.

One consequence: examples are validated only on the maximum supported Terraform version, because the
exclusion also removes them from the minimum-version matrix jobs. The root module and `tests/local/`
are still checked against the minimum, which is what `required_version` asserts.

### Why `wrappers/` is hand-maintained

The upstream `terraform_wrapper_module_for_each` pre-commit hook is not enabled. It hardcodes
`terraform-aws-modules` and `aws` in the source addresses it generates, and it overwrites
`wrappers/README.md` on every run with an Amazon S3 example whose inputs do not exist in this module.
It offers no way to skip that file, so restoring a correct one leaves the gate permanently dirty.

[`scripts/check-wrapper-sync.sh`](scripts/check-wrapper-sync.sh) replaces the one useful thing the hook
did: it fails if a root variable is not passed through `wrappers/main.tf`. When you add a variable to
the root module, add the matching line to the wrapper in the same change.

## Behaviours to guard against

Where each is caught differs, and that determines whether a test can see it. A provider schema
validator runs during `terraform validate`, but only against values the config already knows: anything
arriving through a module input is unknown at that point, so through this module those checks surface
later, at plan or apply. The module's own `variable` validations have no such limitation.

1. **`temporalcloud_group_access.id` is an input, not a computed address.** The provider requires it
   and expects the ID of the group the access applies to. It reads like a Terraform resource ID and is
   not one. Nothing catches a wrong value; it simply edits the wrong group.
2. **The account role and namespace permissions are separate vocabularies.** `account_access` takes
   `owner`, `admin`, `developer`, `read` or `none`; `namespace_accesses[*].permission` takes `admin`,
   `write` or `read`. `write` is not a valid account role and `developer` is not a valid namespace
   permission. Both are matched case-insensitively. Note that `account_access` on `temporalcloud_user`
   accepts a *different* set — it adds `financeadmin` and `metricsread` and drops `none` — so do not
   share a validation between the two. Caught by this module's variable validations.
3. **`owner` and `admin` cannot hold explicit namespace permissions.** Those roles already reach every
   namespace, and the provider rejects the combination with `namespace_accesses must be empty when
   account_access is admin`. The module does not duplicate the check: a variable validation would have
   to read two variables at once, which needs Terraform 1.9 and this module's floor is 1.5.7.
4. **Empty sets are rejected**, for both `account_access_custom_roles` and `namespace_accesses`. Both
   the provider and this module's variable validations reject `[]`; the module omits the attribute
   instead. `users` differs — nothing rejects an empty set, but the resource requires the attribute, so
   the module creates no membership resource at all.
5. **`owner` is import-only.** It cannot be created, updated or deleted without Temporal support. The
   provider accepts it in the config, so this one really does reach the API before failing.

When writing assertions, note that outputs wrapped in `try(x, [])` evaluate to a *tuple*, so
`output.group_namespace_accesses == tolist([])` is false even against an empty result. Compare with
`length()` and index elementwise instead.

## Running the apply tests

They create and destroy **real, billable** groups and namespaces. Point them at a scratch account.

```bash
export TEMPORAL_CLOUD_API_KEY="<key for a scratch account>"
terraform init
terraform test -verbose
```

Without a key every run block is skipped, which is a cheap way to check that the test files parse:

```text
Failure! 0 passed, 0 failed, 11 skipped.
```

Two inputs cannot be covered on apply at all — membership, because every user ID belongs to a real
person, and custom roles, because the resource that creates them lives in another module.
[`tests/README.md`](tests/README.md) records the reasoning and what a maintainer would need in order to
run them by hand. An honest gap is preferred to a permanently-red test.

In CI they run from the **Apply Tests** workflow. Its first step is
`scripts/check-api.sh`, a liveness check that confirms the API answers and the key
is accepted, so a credentials problem fails immediately rather than surfacing
minutes later as a resource that would not create.

Apply Tests is chained after Pre-Commit, and Release after Apply Tests, so a merge
to main runs:

```text
push to main -> Pre-Commit -> Apply Tests -> Release
```

A release is therefore only cut from code that passed both the static gate and the
tests that apply against a real account. Any failure in the chain stops it.

Apply Tests never runs on pull requests: forks cannot read secrets and every run
costs money. It also runs weekly, and on demand. Runs are serialized with
`cancel-in-progress: false`, because cancelling mid-apply would abandon a real resource with no
destroy.

Resources created by the tests are prefixed so leftovers from an interrupted run are identifiable; see
[`tests/README.md`](tests/README.md). Note that `scripts/check-orphans.sh` cannot see leftover
**groups** — no data source enumerates them — so a clean result from it is not proof that nothing was
left behind.

## Pull requests

Titles must be [conventional commits](https://www.conventionalcommits.org/) — `feat:`, `fix:`, `docs:`,
`ci:`, `chore:`, `test:` or `refactor:` — with a capitalised subject. Squash-merge makes the title the commit message, and
semantic-release derives the next version from it, so an invalid title silently breaks versioning. A
workflow enforces this.

`CHANGELOG.md` and tags are generated on merge. Never bump versions by hand.

If CI reports fewer checks than usual, check whether the pull request has merge conflicts: GitHub skips
`pull_request` workflows when it cannot compute a merge ref, with no failed check to show for it.
