variable "alarm_unauthorized_arn" {
  type        = string
  description = "ARN of the PHIUnauthorizedAccess CloudWatch Alarm"
}

variable "alarm_bulk_arn" {
  type        = string
  description = "ARN of the PHIBulkAccess CloudWatch Alarm"
}

variable "log_group_name" {
  type        = string
  description = "CloudWatch Log Group name for the Log Insights widget"
}

variable "aws_region" {
  type        = string
  description = "AWS region (used to scope the log insights widget)"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
}
