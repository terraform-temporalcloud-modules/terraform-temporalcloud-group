variable "idp_group_id" {
  description = "The group's ID in the identity provider, as sent to Temporal Cloud over SCIM. Find it in the identity provider's admin console — for example, the Object ID of an Entra ID group"
  type        = string
}

variable "namespace_id" {
  description = "ID of the namespace to grant the group access to, in the form `<namespace>.<account_id>`"
  type        = string
}
