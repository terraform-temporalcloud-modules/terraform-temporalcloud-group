# SCIM-managed Temporal Cloud group example

Configuration in this directory grants permissions to a group that **already exists** because an
identity provider created it over SCIM. Terraform manages the group's roles and namespace permissions;
the identity provider keeps managing the group itself and everybody in it.

This is the split that matters when SCIM is enabled:

| Owned by the identity provider | Owned by Terraform |
| --- | --- |
| The group's existence and name | The group's account-level role |
| The group's membership | The group's per-namespace permissions |

Temporal Cloud
[assigns the first column to the integration](https://docs.temporal.io/cloud/manage-access/user-groups):
a SCIM group cannot be created or deleted except through it, and its membership is managed through it.
`temporalcloud_group` always creates a new group rather than adopting one, and
`temporalcloud_group_members` replaces a group's whole member list — so this example uses neither, and
gives the module the group's ID instead.

## Usage

To run this example you need to execute:

```bash
export TEMPORAL_CLOUD_API_KEY="<your-api-key>"

terraform init
terraform plan
terraform apply
```

`idp_group_id` is the group's ID **in the identity provider**, not in Temporal Cloud — the Object ID of
an Entra ID group, or the group ID from an Okta SCIM application. The
`temporalcloud_scim_group` data source translates it into the Temporal Cloud group ID that
`group_id` needs.

```bash
terraform apply \
  -var='idp_group_id=00000000-0000-0000-0000-000000000000' \
  -var='namespace_id=orders-prod.a1b2c3'
```

Note that this example changes access to a real namespace. Run `terraform destroy` when you no longer
need it; that removes the permissions this configuration granted, and leaves the group itself alone.

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
| <a name="module_group_access"></a> [group\_access](#module\_group\_access) | terraform-temporalcloud-modules/group/temporalcloud | ~> 2.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [temporalcloud_scim_group.this](https://registry.terraform.io/providers/temporalio/temporalcloud/latest/docs/data-sources/scim_group) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_idp_group_id"></a> [idp\_group\_id](#input\_idp\_group\_id) | The group's ID in the identity provider, as sent to Temporal Cloud over SCIM. Find it in the identity provider's admin console — for example, the Object ID of an Entra ID group | `string` | n/a | yes |
| <a name="input_namespace_id"></a> [namespace\_id](#input\_namespace\_id) | ID of the namespace to grant the group access to, in the form `<namespace>.<account_id>` | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_group_account_access"></a> [group\_account\_access](#output\_group\_account\_access) | The group's role on the account |
| <a name="output_group_id"></a> [group\_id](#output\_group\_id) | The Temporal Cloud identifier of the SCIM-provisioned group |
| <a name="output_group_namespace_accesses"></a> [group\_namespace\_accesses](#output\_group\_namespace\_accesses) | The group's complete namespace access map |
| <a name="output_scim_group_name"></a> [scim\_group\_name](#output\_scim\_group\_name) | The group's name, as the identity provider set it |
<!-- END_TF_DOCS -->

## License

Apache-2.0 licensed. See [LICENSE](../../LICENSE).
