variable "log_group_name" {
  type        = string
  description = "CloudWatch Log Group name to attach metric filters to"
}

variable "alarm_email" {
  type        = string
  description = "Email address for SNS alarm notifications"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
}
