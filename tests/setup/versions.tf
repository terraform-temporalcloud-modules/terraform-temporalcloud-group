terraform {
  required_version = ">= 1.5.7"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
    # Declared but unused. The calling .tftest.hcl passes its `temporalcloud`
    # provider into every run block, and without this entry Terraform resolves the
    # name to hashicorp/temporalcloud here and fails on the type mismatch.
    temporalcloud = {
      source  = "temporalio/temporalcloud"
      version = ">= 1.6.0"
    }
  }
}
