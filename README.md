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
| <a name="input_account_access"></a> [account\_access](#input\_account\_access) | The group's role on the account: `owner`, `admin`, `developer`, `read` or `none`, matched case-insensitively. Use `none` for a group whose permissions come entirely from `namespace_accesses`. `owner` can only be adopted by import — it cannot be created, updated or deleted without Temporal support. Required unless `create_group_access` is `false` | `string` | `""` | no |
| <a name="input_account_access_custom_roles"></a> [account\_access\_custom\_roles](#input\_account\_access\_custom\_roles) | IDs of custom roles granted at account level, in addition to the built-in role in `account_access`. Omit rather than passing an empty set | `set(string)` | `null` | no |
| <a name="input_create_group"></a> [create\_group](#input\_create\_group) | Controls if the group should be created. Set to `false` and supply `group_id` to manage the access and membership of a group that already exists, such as one provisioned by SCIM | `bool` | `true` | no |
| <a name="input_create_group_access"></a> [create\_group\_access](#input\_create\_group\_access) | Controls if the group's access should be managed. Requires either `create_group = true` or `group_id` set to an existing group | `bool` | `false` | no |
| <a name="input_create_group_members"></a> [create\_group\_members](#input\_create\_group\_members) | Controls if the group's membership should be managed. Requires either `create_group = true` or `group_id` set to an existing group. Leave `false` for SCIM-provisioned groups, whose membership is owned by the identity provider | `bool` | `false` | no |
| <a name="input_group_id"></a> [group\_id](#input\_group\_id) | The ID of an existing group to attach access and membership to. Used only when `create_group` is `false`, for groups created outside Terraform — a SCIM-provisioned group, for example, whose ID comes from the `temporalcloud_scim_group` data source | `string` | `""` | no |
| <a name="input_members_timeouts"></a> [members\_timeouts](#input\_members\_timeouts) | Create and delete timeouts for the group membership, as duration strings such as `30s` or `2h45m` | <pre>object({<br/>    create = optional(string)<br/>    delete = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the group. Required unless `create_group` is `false` | `string` | `""` | no |
| <a name="input_namespace_accesses"></a> [namespace\_accesses](#input\_namespace\_accesses) | Per-namespace permissions for the group, as a set of `namespace_id` and `permission` pairs. `permission` is `admin`, `write` or `read`, matched case-insensitively. This replaces the group's entire namespace access map, so it must list every namespace the group can reach. Leave unset for groups whose `account_access` is `owner` or `admin` — those roles already reach every namespace and explicit permissions are rejected. Omit rather than passing an empty set | <pre>set(object({<br/>    namespace_id = string<br/>    permission   = string<br/>  }))</pre> | `null` | no |
| <a name="input_timeouts"></a> [timeouts](#input\_timeouts) | Create and delete timeouts for the group, as duration strings such as `30s` or `2h45m` | <pre>object({<br/>    create = optional(string)<br/>    delete = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_users"></a> [users](#input\_users) | IDs of the users that make up the group, as returned by the `temporalcloud_users` data source or the `id` of a `temporalcloud_user` resource. This replaces the group's entire membership, so users added outside Terraform are removed on the next apply. An empty set creates no membership resource | `set(string)` | `[]` | no |

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
