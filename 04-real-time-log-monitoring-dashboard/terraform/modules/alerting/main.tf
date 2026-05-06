resource "aws_sns_topic" "alerts" {
  name = "phi-audit-alerts"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_cloudwatch_log_metric_filter" "unauthorized" {
  name           = "PHIUnauthorizedAccessFilter"
  log_group_name = var.log_group_name
  pattern        = "[timestamp, requestId, level=\"ERROR\" || level=\"WARN\", message=\"*UNAUTHORIZED*\"]"

  metric_transformation {
    namespace = "PHIAudit"
    name      = "PHIUnauthorizedAccess"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "bulk" {
  name           = "PHIBulkAccessFilter"
  log_group_name = var.log_group_name
  pattern        = "[timestamp, requestId, level=\"WARN\" || level=\"ERROR\", message=\"*bulk*\" || message=\"*BULK*\"]"

  metric_transformation {
    namespace = "PHIAudit"
    name      = "PHIBulkAccess"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "unauthorized" {
  alarm_name          = "PHIUnauthorizedAccess"
  namespace           = "PHIAudit"
  metric_name         = "PHIUnauthorizedAccess"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  period              = 300
  evaluation_periods  = 1
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "bulk" {
  alarm_name          = "PHIBulkAccess"
  namespace           = "PHIAudit"
  metric_name         = "PHIBulkAccess"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 50
  period              = 600
  evaluation_periods  = 1
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  tags                = var.tags
}
