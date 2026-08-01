variable "member_emails" {
  description = "Email addresses of users to place in the group. They must already be members of the Temporal Cloud account — this example looks their IDs up rather than inviting anybody. Leave empty to create the group and its access without touching membership"
  type        = list(string)
  default     = []
}
