variable "test_resource_prefix" {
  description = "Prefix identifying resources created by the test suite. Anything matching it after a test run has finished is a leftover"
  type        = string
  default     = "yulei-tftest-grp-"
}
