# Wrapper for the Temporal Cloud group module

The configuration in `wrappers/` implements the single module wrapper pattern, which allows managing
several copies of this module from one call in places where the native `for_each` on a module block is
not available — most commonly Terragrunt.

This wrapper adds no functionality of its own. Every key under `items` accepts any input the root
module accepts, and `defaults` supplies values shared by all items.

Contributors: see [CONTRIBUTING.md](../CONTRIBUTING.md) for how these files are maintained.

## Usage with Terraform

```hcl
module "groups" {
  source = "terraform-temporalcloud-modules/group/temporalcloud//wrappers"

  # Shared by every item unless the item overrides it.
  defaults = {
    create_group_access = true
    account_access      = "read"
  }

  items = {
    platform = {
      name           = "platform-engineering"
      account_access = "developer" # overrides the default above

      namespace_accesses = [
        {
          namespace_id = module.orders.namespace_id
          permission   = "admin"
        },
      ]
    }

    support = {
      name = "support"

      namespace_accesses = [
        {
          namespace_id = module.orders.namespace_id
          permission   = "read"
        },
      ]
    }

    # Access only, for a group the identity provider owns.
    contractors = {
      create_group   = false
      group_id       = data.temporalcloud_scim_group.contractors.id
      account_access = "none"

      namespace_accesses = [
        {
          namespace_id = module.sandbox.namespace_id
          permission   = "write"
        },
      ]
    }
  }
}
```

Outputs are keyed by the same map keys:

```hcl
output "platform_group_id" {
  value = module.groups.wrapper["platform"].group_id
}
```

## Usage with Terragrunt

`terragrunt.hcl`:

```hcl
terraform {
  source = "tfr:///terraform-temporalcloud-modules/group/temporalcloud//wrappers?version=1.0.0"
  # Alternative source:
  # source = "git::git@github.com:terraform-temporalcloud-modules/terraform-temporalcloud-group.git//wrappers?ref=v1.0.0"
}

inputs = {
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

Pin `?version=` / `?ref=` to a released tag rather than a branch, so a wrapper upgrade is a deliberate
change.

## Inputs

| Name | Description | Type | Default |
| ---- | ----------- | ---- | ------- |
| `defaults` | Default values applied to every group in `items`, unless that item overrides them | `any` | `{}` |
| `items` | Map of groups to create; each key becomes an instance of the module | `any` | `{}` |

## Outputs

| Name | Description |
| ---- | ----------- |
| `wrapper` | Map of module outputs, keyed by the same keys as `items` |
