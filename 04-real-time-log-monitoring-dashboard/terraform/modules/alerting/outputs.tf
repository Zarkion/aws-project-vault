output "sns_topic_arn" {
  description = "ARN of the PHI audit alerts SNS topic"
  value       = aws_sns_topic.alerts.arn
}

output "alarm_unauthorized_arn" {
  description = "ARN of the PHIUnauthorizedAccess alarm"
  value       = aws_cloudwatch_metric_alarm.unauthorized.arn
}

output "alarm_bulk_arn" {
  description = "ARN of the PHIBulkAccess alarm"
  value       = aws_cloudwatch_metric_alarm.bulk.arn
}
