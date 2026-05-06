resource "aws_cloudwatch_dashboard" "phi_audit" {
  dashboard_name = "PHI-Access-Audit-Dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "PHI Access Anomaly"
          region  = var.aws_region
          view    = "timeSeries"
          period  = 900
          stat    = "Sum"
          metrics = [
            ["PHIAudit", "PHIUnauthorizedAccess", { label = "Unauthorized Access" }],
            ["PHIAudit", "PHIBulkAccess", { label = "Bulk Access" }]
          ]
        }
      },
      {
        type   = "alarm"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Alarm Status"
          alarms = [var.alarm_unauthorized_arn, var.alarm_bulk_arn]
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          title   = "Recent Critical Incidents"
          region  = var.aws_region
          view    = "table"
          query   = "SOURCE '${var.log_group_name}' | fields @timestamp, actorId, resourceAccessed, actionType, severity | filter severity = \"CRITICAL\" | sort @timestamp desc | limit 20"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          title   = "Incident Volume by Action Type"
          region  = var.aws_region
          view    = "bar"
          period  = 900
          metrics = [
            ["PHIAudit", "PHIUnauthorizedAccess", { id = "m1", label = "Unauthorized Access", stat = "Sum" }],
            ["PHIAudit", "PHIBulkAccess", { id = "m2", label = "Bulk Access", stat = "Sum" }],
            [{ expression = "METRICS()", id = "e1", label = "All PHI Incidents", visible = false }]
          ]
        }
      }
    ]
  })
}
