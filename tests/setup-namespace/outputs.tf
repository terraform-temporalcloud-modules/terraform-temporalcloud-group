output "group_name" {
  description = "Unique group name for this test run, prefixed `yulei-tftest-grp-` so leftovers from an interrupted run are identifiable in the Temporal Cloud account"
  value       = "yulei-tftest-grp-${random_pet.this.id}-ns"
}

output "namespace_id" {
  description = "ID of the throwaway namespace the group is granted access to"
  value       = temporalcloud_namespace.this.id
}

output "namespace_name" {
  description = "Name of the throwaway namespace, prefixed `yulei-tftest-grp-` so the orphan check can spot it if a run is interrupted"
  value       = temporalcloud_namespace.this.name
}
