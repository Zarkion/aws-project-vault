output "log_group_name" {
  description = "CloudWatch Log Group name"
  value       = aws_cloudwatch_log_group.app_logs.name
}

output "sns_topic_arn" {
  description = "SNS alert topic ARN"
  value       = module.alerting.sns_topic_arn
}

output "lambda_function_arn" {
  description = "LogAlertProcessor ARN"
  value       = module.lambda.lambda_function_arn
}

output "dynamodb_table_name" {
  description = "DynamoDB audit incidents table name"
  value       = aws_dynamodb_table.audit_incidents.name
}

output "dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=PHI-Access-Audit-Dashboard"
}
