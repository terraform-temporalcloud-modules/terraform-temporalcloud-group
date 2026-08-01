output "group_name" {
  description = "Unique group name for this test run, prefixed `yulei-tftest-grp-` so leftovers from an interrupted run are identifiable in the Temporal Cloud account"
  # `yulei-` identifies the owner, `tftest-` distinguishes test groups from
  # anything created by hand.
  value = "yulei-tftest-grp-${random_pet.this.id}"
}
