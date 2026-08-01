# Temporal Cloud Group Terraform module

[![CI](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-group/actions/workflows/pre-commit.yml/badge.svg?branch=main)](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-group/actions/workflows/pre-commit.yml?query=branch%3Amain)
[![Apply Tests](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-group/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-group/actions/workflows/test.yml?query=branch%3Amain)

Terraform module which creates a [Temporal Cloud](https://temporal.io/cloud) user group, together with
its account and namespace permissions and its membership.

Both badges report the state of `main`. **CI** covers formatting, linting,
documentation and `terraform validate`, and runs on every pull request and again
after merge. **Apply Tests** creates and destroys real groups against a live
Temporal Cloud account, weekly and on demand — the only check that proves the API
accepts what this module sends.

## When to use this module

**This is the module that grants access.** Whatever else your account uses, something has to say which
namespaces a group can reach and at what level, and that is what lives here.

If your account has SAML and SCIM, this is the module you want — not
[`user`](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-user). Those two
features cover authentication and provisioning, and stop short of permissions:

| Concern | Owned by |
| --- | --- |
| Authentication — signing in | [SAML SSO](https://docs.temporal.io/cloud/saml) |
| Which people exist, and their group membership | [SCIM](https://docs.temporal.io/cloud/scim), from your identity provider |
| **What a group is allowed to do** | **this module** |
| Machine access for workers and CI | [`service-account`](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-service-account) — never a group |

Temporal Cloud's SCIM documentation is explicit that roles are assigned to a group *after* it syncs.
So SCIM delivers a group with the right people in it and stops; `account_access` and
`namespace_accesses` remain yours to set, and granting them to groups rather than to individuals is
what makes a synced user's access follow from their membership.

Two ways to use it, depending on where the group comes from:

- **The group is provisioned by SCIM, or otherwise already exists.** Set `create_group = false` and pass
  `group_id`, enable `create_group_access`, and leave `create_group_members` off so the identity
  provider stays the only writer of membership. See
  [Groups provisioned by SCIM](#groups-provisioned-by-scim).
- **You own the group outright.** Let the module create it and manage membership here too. Appropriate
  when there is no SCIM integration — both SAML and SCIM are paid features — or for a group that has no
  equivalent in the directory.

Because `temporalcloud_group_access` owns a group's **entire** access map rather than individual
entries, exactly one configuration may manage a given group's access. Two module calls pointing at the
same `group_id` will overwrite each other on every apply.

## Requirements

The `temporalcloud` provider authenticates with an API key, read from the `TEMPORAL_CLOUD_API_KEY`
environment variable:

```bash
export TEMPORAL_CLOUD_API_KEY="<your-api-key>"
```

The provider authenticates when it initialises, so a key is needed even for a `terraform plan` that
would create nothing. Keep the key out of version control — an untracked `.env` file rather than a
committed `.tfvars`.

## Usage

### A group with account-level access

The group's role on the account is the coarsest control: it applies everywhere and needs no namespace
to point at.

```hcl
module "group" {
  source  = "terraform-temporalcloud-modules/group/temporalcloud"
  version = "~> 1.0"

  name = "platform-engineering"

  create_group_access = true
  account_access      = "developer"
}
```

### Namespace permissions

`namespace_accesses` grants per-namespace permissions. It is a set, and it replaces the group's whole
namespace access map on every apply, so it has to list every namespace the group should reach.

```hcl
module "group" {
  source  = "terraform-temporalcloud-modules/group/temporalcloud"
  version = "~> 1.0"

  name = "support"

  create_group_access = true

  # `none` gives no account-wide role, so the group reaches exactly the two
  # namespaces below and nothing else.
  account_access = "none"

  namespace_accesses = [
    {
      namespace_id = module.orders.namespace_id
      permission   = "read"
    },
    {
      namespace_id = module.payments.namespace_id
      permission   = "write"
    },
  ]
}
```

### Membership

Membership is set by user **ID**, not email address. The `temporalcloud_users` data source lists the
account's existing users; `temporalcloud_user` invites new ones and belongs to a different module in
this family.

```hcl
data "temporalcloud_users" "all" {}

module "group" {
  source  = "terraform-temporalcloud-modules/group/temporalcloud"
  version = "~> 1.0"

  name = "platform-engineering"

  create_group_members = true

  users = [
    for u in data.temporalcloud_users.all.users : u.id
    if endswith(u.email, "@example.com")
  ]
}
```

## Groups provisioned by SCIM

If your account uses SCIM, the identity provider — Entra ID, Okta and so on — creates groups in
Temporal Cloud and keeps their membership in sync. Temporal Cloud
[assigns both to the integration](https://docs.temporal.io/cloud/manage-access/user-groups): a SCIM
group cannot be created or deleted except through it, and its membership is managed through it.
**Terraform must not own either.**

- `temporalcloud_group` always creates a new group; it cannot adopt an existing one. Since a SCIM group
  cannot be created any other way, a SCIM group reaches this module through `group_id` with
  `create_group = false`.
- Leave `create_group_members` off. `temporalcloud_group_members` replaces a group's whole member list
  on every apply, and that list belongs to the identity provider.

Roles and namespace permissions are assigned in Temporal Cloud once a group has synced, rather than
carried across from the identity provider, so they are the part of a SCIM group Terraform should own.
Set `create_group = false`, resolve the group's Temporal Cloud ID from its identity provider ID with
the `temporalcloud_scim_group` data source, and leave `create_group_members` off:

```hcl
data "temporalcloud_scim_group" "contractors" {
  # The group's Object ID in the identity provider, not its Temporal Cloud ID.
  idp_id = "00000000-0000-0000-0000-000000000000"
}

module "contractor_access" {
  source  = "terraform-temporalcloud-modules/group/temporalcloud"
  version = "~> 1.0"

  create_group = false
  group_id     = data.temporalcloud_scim_group.contractors.id

  create_group_access = true
  account_access      = "none"

  namespace_accesses = [
    {
      namespace_id = module.sandbox.namespace_id
      permission   = "write"
    },
  ]

  # Owned by the identity provider.
  create_group_members = false
}
```

The same pattern adopts any group created outside Terraform, SCIM or not — supply `group_id` directly
when you already have the Temporal Cloud ID.

## Notes

Provider and Temporal Cloud behaviours worth knowing before you plan:

- **`account_access` and `permission` are different vocabularies.** `account_access` is `owner`,
  `admin`, `developer`, `read` or `none`. `namespace_accesses[*].permission` is `admin`, `write` or
  `read`. `write` is not an account role, `developer` is not a namespace permission, and both are
  matched case-insensitively.
- **`owner` and `admin` cannot hold explicit namespace permissions.** Those roles already reach every
  namespace, so combining them with `namespace_accesses` is rejected — `namespace_accesses must be
  empty when account_access is admin`. Pair `namespace_accesses` with `developer`, `read` or `none`.
- **`owner` can only be adopted by import.** It cannot be created, updated or deleted without Temporal
  support.
- **Both child resources replace, they do not merge.** `namespace_accesses` owns the group's entire
  access map and `users` owns its entire membership, so anything granted or added outside Terraform is
  removed on the next apply.
- **Empty sets are rejected**, for both `namespace_accesses` and `account_access_custom_roles` — omit
  the variable instead. `users` is the exception: an empty set creates no membership resource rather
  than sending one.
- **Only one membership resource may exist per group.** Calling this module twice against the same
  `group_id` with `create_group_members = true` in both makes each apply overwrite the other's members.

## Examples

- [complete](examples/complete) — a group with an account role, namespace permissions and membership,
  with the namespace it points at created alongside
- [scim-managed-group](examples/scim-managed-group) — permissions for a group the identity provider
  owns, leaving the group and its membership to SCIM

## Managing several groups

The [`wrappers`](wrappers) submodule creates many groups from one call, for use with Terragrunt or
anywhere a `for_each` on the module block is awkward:

```hcl
module "groups" {
  source  = "terraform-temporalcloud-modules/group/temporalcloud//wrappers"
  version = "~> 1.0"

  defaults = {
    create_group_access = true
    account_access      = "read"
  }

  items = {
    platform = { name = "platform-engineering", account_access = "developer" }
    support  = { name = "support" }
  }
}
```

## Which inputs are required

Every input carries a Terraform default, so the generated **Inputs** table below reports
`Required: no` for all of them. That is what lets `create_group = false` hand the module an existing
group instead of creating one: a module with switchable parts cannot demand a value for every input.
What is genuinely required follows the three gates, and these tables are the record of it.

Where a rule is caught differs, and the tables say so:

- **validate** — this module's own `variable` validations. They run under `terraform validate` and need
  no credentials.
- **plan** — the provider's schema validators. They see a module input only once its value is known,
  which is at plan rather than validate. The provider authenticates when it initialises, so reaching
  them needs an API key.
- **apply** — nothing catches it beforehand.
- **nothing** — no resource and no error. Two inputs behave this way when omitted; they are the ones
  worth reading twice.

### The group itself

Exactly one of these is required, and which one depends on `create_group`:

| Input | Required when | Omitting it |
| --- | --- | --- |
| `name` | `create_group = true` (the default) | The group is sent with an empty name. Nothing before **apply** objects. |
| `group_id` | `create_group = false` | **Nothing** happens. With no group to attach to, `create_group_access` and `create_group_members` both produce no resource, no error, and an empty `group_id` output. |

`group_id` is ignored when `create_group = true` — access and membership always attach to the group
the module created.

### With `create_group_access = true`

| Input | Omitting it |
| --- | --- |
| `account_access` | Fails at **plan**: `Attribute account_access value must be one of: ["owner" "admin" "developer" "read" "none"], got: ""`. The provider requires an account role and infers none. Use `none` for a group whose permissions come entirely from `namespace_accesses`. |

### With `create_group_members = true`

| Input | Omitting it |
| --- | --- |
| `users` | **Nothing** happens. The provider requires the attribute and rejects an empty set, so rather than send one the module creates no membership resource — silently. A group whose membership never appears is usually this. |

### Combinations that are rejected

| Combination | Caught at | Error |
| --- | --- | --- |
| `account_access` of `owner` or `admin` with `namespace_accesses` | plan | `namespace_accesses must be empty when account_access is <role>` |
| `[]` for `namespace_accesses` or `account_access_custom_roles` | validate | `Empty … sets are not accepted by the provider. Omit the variable instead.` |
| A role outside `owner`, `admin`, `developer`, `read`, `none`, or a namespace permission outside `admin`, `write`, `read` | validate | `Account access must be one of: …` / `Namespace access permission must be one of: …` |

### Optional

- **Access refinement** — `namespace_accesses`, `account_access_custom_roles`. Without them the group
  reaches exactly what its `account_access` role reaches, and nothing more.
- **Timeouts** — `timeouts`, `members_timeouts`. The provider's own create and delete timeouts apply.
- **Gates** — `create_group` (on by default), `create_group_access` and `create_group_members` (both
  off). With all three off the module creates nothing.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_temporalcloud"></a> [temporalcloud](#requirement\_temporalcloud) | >= 1.6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_temporalcloud"></a> [temporalcloud](#provider\_temporalcloud) | >= 1.6.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [temporalcloud_group.this](https://registry.terraform.io/providers/temporalio/temporalcloud/latest/docs/resources/group) | resource |
| [temporalcloud_group_access.this](https://registry.terraform.io/providers/temporalio/temporalcloud/latest/docs/resources/group_access) | resource |
| [temporalcloud_group_members.this](https://registry.terraform.io/providers/temporalio/temporalcloud/latest/docs/resources/group_members) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_access"></a> [account\_access](#input\_account\_access) | The group's role on the account: `owner`, `admin`, `developer`, `read` or `none`, matched case-insensitively. Required when `create_group_access` is `true` — there is no account role the provider will infer, and the empty default is rejected at plan. Use `none` for a group whose permissions come entirely from `namespace_accesses`. `owner` can only be adopted by import — it cannot be created, updated or deleted without Temporal support | `string` | `""` | no |
| <a name="input_account_access_custom_roles"></a> [account\_access\_custom\_roles](#input\_account\_access\_custom\_roles) | IDs of custom roles granted at account level, in addition to the built-in role in `account_access`. Optional; the group holds only the role in `account_access` when unset. Omit rather than passing an empty set | `set(string)` | `null` | no |
| <a name="input_create_group"></a> [create\_group](#input\_create\_group) | Controls if the group should be created. Left `true`, `name` is required. Set to `false` and supply `group_id` to manage the access and membership of a group that already exists, such as one provisioned by SCIM | `bool` | `true` | no |
| <a name="input_create_group_access"></a> [create\_group\_access](#input\_create\_group\_access) | Controls if the group's access should be managed. Setting it to `true` makes `account_access` required. Requires either `create_group = true` or `group_id` set to an existing group; with neither, no access resource is created | `bool` | `false` | no |
| <a name="input_create_group_members"></a> [create\_group\_members](#input\_create\_group\_members) | Controls if the group's membership should be managed. Setting it to `true` makes a non-empty `users` required. Requires either `create_group = true` or `group_id` set to an existing group; with neither, no membership resource is created. Leave `false` for SCIM-provisioned groups, whose membership is owned by the identity provider | `bool` | `false` | no |
| <a name="input_group_id"></a> [group\_id](#input\_group\_id) | The ID of an existing group to attach access and membership to. Required when `create_group` is `false`, and ignored otherwise. Leaving it empty with `create_group = false` leaves nothing to attach to, so the module creates no resources at all and reports no error. For groups created outside Terraform — a SCIM-provisioned group, for example, whose ID comes from the `temporalcloud_scim_group` data source | `string` | `""` | no |
| <a name="input_members_timeouts"></a> [members\_timeouts](#input\_members\_timeouts) | Create and delete timeouts for the group membership, as duration strings such as `30s` or `2h45m`. Optional; the provider's own defaults apply to whichever is unset | <pre>object({<br/>    create = optional(string)<br/>    delete = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the group. Required when `create_group` is `true`; the empty default is sent as an empty name and nothing rejects it before apply. Ignored when `create_group` is `false` | `string` | `""` | no |
| <a name="input_namespace_accesses"></a> [namespace\_accesses](#input\_namespace\_accesses) | Per-namespace permissions for the group, as a set of `namespace_id` and `permission` pairs. `permission` is `admin`, `write` or `read`, matched case-insensitively. Optional; without it the group reaches namespaces only through its `account_access` role. This replaces the group's entire namespace access map, so it must list every namespace the group can reach. Leave unset for groups whose `account_access` is `owner` or `admin` — those roles already reach every namespace and explicit permissions are rejected. Omit rather than passing an empty set | <pre>set(object({<br/>    namespace_id = string<br/>    permission   = string<br/>  }))</pre> | `null` | no |
| <a name="input_timeouts"></a> [timeouts](#input\_timeouts) | Create and delete timeouts for the group, as duration strings such as `30s` or `2h45m`. Optional; the provider's own defaults apply to whichever is unset | <pre>object({<br/>    create = optional(string)<br/>    delete = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_users"></a> [users](#input\_users) | IDs of the users that make up the group, as returned by the `temporalcloud_users` data source or the `id` of a `temporalcloud_user` resource. Required, and non-empty, when `create_group_members` is `true`: the provider requires the attribute, so rather than send an empty membership the module creates no membership resource at all and reports no error. This replaces the group's entire membership, so users added outside Terraform are removed on the next apply | `set(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_group_account_access"></a> [group\_account\_access](#output\_group\_account\_access) | The group's role on the account |
| <a name="output_group_account_access_custom_roles"></a> [group\_account\_access\_custom\_roles](#output\_group\_account\_access\_custom\_roles) | IDs of the custom roles granted to the group at account level. Empty when none are granted |
| <a name="output_group_id"></a> [group\_id](#output\_group\_id) | The unique identifier of the group. Echoes `group_id` when the module manages an existing group rather than creating one |
| <a name="output_group_members"></a> [group\_members](#output\_group\_members) | IDs of the users that make up the group |
| <a name="output_group_name"></a> [group\_name](#output\_group\_name) | The name of the group. Empty when the module manages a group it did not create |
| <a name="output_group_namespace_accesses"></a> [group\_namespace\_accesses](#output\_group\_namespace\_accesses) | The group's complete namespace access map, as a set of `namespace_id` and `permission` pairs. Empty when the group has no namespace access |
| <a name="output_group_state"></a> [group\_state](#output\_group\_state) | The current state of the group. Empty when the module manages a group it did not create |
<!-- END_TF_DOCS -->

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow, how the test layers are arranged,
and the Temporal Cloud API behaviours the tests exist to guard against.

## License

Apache-2.0 licensed. See [LICENSE](LICENSE).
