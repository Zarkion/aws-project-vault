variable "dynamodb_table_arn" {
  type        = string
  description = "ARN of the DynamoDB audit incidents table"
}

variable "dynamodb_table_name" {
  type        = string
  description = "Name of the DynamoDB audit incidents table"
}

variable "aws_region" {
  type        = string
  description = "AWS region the function is deployed into"
}

variable "log_group_name" {
  type        = string
  description = "CloudWatch Log Group name to subscribe to"
}

variable "log_group_arn" {
  type        = string
  description = "CloudWatch Log Group ARN (used for lambda:InvokeFunction source ARN)"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
}
