variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region to deploy into"
}

variable "log_group_name" {
  type        = string
  default     = "/aws/ehr/application"
  description = "CloudWatch Log Group name for the EHR application"
}

variable "alarm_email" {
  type        = string
  description = "Email address for SNS alarm notifications"
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "Environment tag applied to all resources"
}
