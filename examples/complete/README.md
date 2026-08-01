# Complete Temporal Cloud group example

Configuration in this directory creates a Temporal Cloud group, grants it an account-level role and
write access to a namespace, and optionally sets its membership.

It creates its own namespace so it runs unmodified. In a real configuration those namespace IDs come
from wherever your namespaces are already managed.

## Usage

To run this example you need to execute:

```bash
export TEMPORAL_CLOUD_API_KEY="<your-api-key>"

terraform init
terraform plan
terraform apply
```

Note that this example creates resources which cost money. Run `terraform destroy` when you no longer
need them.

## Membership

Membership is set by user **ID**, not by email address, and Temporal Cloud has no data source that
resolves one to the other directly. This example reads `temporalcloud_users` and filters it, so pass
the addresses of people who are already members of the account:

```bash
terraform apply -var='member_emails=["platform@example.com"]'
```

An address that does not match an existing account member matches nothing — no invitation is sent and
no email is delivered. Inviting someone who is not yet in the account is what `temporalcloud_user`
does, and that resource belongs to a different module in this family.

With `member_emails` left empty, the module creates the group and its access but no membership
resource: `temporalcloud_group_members` requires `users`, so "no members" is expressed by not creating
the resource at all.

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

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_group"></a> [group](#module\_group) | terraform-temporalcloud-modules/group/temporalcloud | ~> 1.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [temporalcloud_namespace.this](https://registry.terraform.io/providers/temporalio/temporalcloud/latest/docs/resources/namespace) | resource |
| [temporalcloud_regions.available](https://registry.terraform.io/providers/temporalio/temporalcloud/latest/docs/data-sources/regions) | data source |
| [temporalcloud_users.all](https://registry.terraform.io/providers/temporalio/temporalcloud/latest/docs/data-sources/users) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_member_emails"></a> [member\_emails](#input\_member\_emails) | Email addresses of users to place in the group. They must already be members of the Temporal Cloud account — this example looks their IDs up rather than inviting anybody. Leave empty to create the group and its access without touching membership | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_group_account_access"></a> [group\_account\_access](#output\_group\_account\_access) | The group's role on the account |
| <a name="output_group_id"></a> [group\_id](#output\_group\_id) | The unique identifier of the group |
| <a name="output_group_members"></a> [group\_members](#output\_group\_members) | IDs of the users that make up the group |
| <a name="output_group_name"></a> [group\_name](#output\_group\_name) | The name of the group |
| <a name="output_group_namespace_accesses"></a> [group\_namespace\_accesses](#output\_group\_namespace\_accesses) | The group's complete namespace access map |
<!-- END_TF_DOCS -->

## License

Apache-2.0 licensed. See [LICENSE](../../LICENSE).
