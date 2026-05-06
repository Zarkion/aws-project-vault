# Terraform Build Spec — HIPAA PHI Access Audit Logging System

This document is a build specification for Claude Code. Implement the infrastructure
described below as a Terraform project. Do not deviate from the naming conventions,
schema, or IAM constraints without flagging it first.

---

## Project Structure

```
├── main.tf
├── variables.tf
├── outputs.tf
├── modules/
│   ├── alerting/        # Metric Filter, Alarm, SNS
│   ├── lambda/          # Lambda function, Subscription Filter, IAM
│   └── dashboard/       # CloudWatch Dashboard
├── lambda/
│   └── log_alert_processor.py
└── README.md
```

---

## State Backend

Use S3 + DynamoDB for remote state. The user will create these manually before
running `terraform init`. Add a `backend "s3"` block with placeholder values the
user can fill in:

```hcl
terraform {
  backend "s3" {
    bucket         = "<your-state-bucket>"
    key            = "hipaa-audit/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "<your-lock-table>"
    encrypt        = true
  }
}
```

---

## Variables (variables.tf)

| Variable | Type | Default | Description |
|---|---|---|---|
| `aws_region` | string | `"us-east-1"` | AWS region to deploy into |
| `log_group_name` | string | `"/aws/ehr/application"` | CloudWatch Log Group name |
| `alarm_email` | string | — | Email address for SNS alarm notifications (no default, required) |
| `environment` | string | `"prod"` | Environment tag applied to all resources |

---

## Resources

### 1. CloudWatch Log Group

- Resource: `aws_cloudwatch_log_group`
- Name: `var.log_group_name`
- Retention: 90 days (`retention_in_days = 90`)

---

### 2. Metric Filters (module: alerting)

Deploy two metric filters on the log group.

**Filter 1 — Unauthorized Access**
- Name: `PHIUnauthorizedAccessFilter`
- Pattern: `UNAUTHORIZED`
- Metric namespace: `PHIAudit`
- Metric name: `PHIUnauthorizedAccess`
- Metric value: `1`

**Filter 2 — Bulk Access**
- Name: `PHIBulkAccessFilter`
- Pattern: `?bulk ?BULK`
- Metric namespace: `PHIAudit`
- Metric name: `PHIBulkAccess`
- Metric value: `1`

---

### 3. CloudWatch Alarms (module: alerting)

**Alarm 1 — PHIUnauthorizedAccess**
- Name: `PHIUnauthorizedAccess`
- Metric: `PHIAudit/PHIUnauthorizedAccess`
- Threshold: `>= 1`
- Period: `300` (5 minutes)
- Evaluation periods: `1`
- Statistic: `Sum`
- Treat missing data: `notBreaching`
- Alarm action: SNS topic ARN

**Alarm 2 — PHIBulkAccess**
- Name: `PHIBulkAccess`
- Metric: `PHIAudit/PHIBulkAccess`
- Threshold: `>= 50`
- Period: `600` (10 minutes)
- Evaluation periods: `1`
- Statistic: `Sum`
- Treat missing data: `notBreaching`
- Alarm action: SNS topic ARN

---

### 4. SNS Topic (module: alerting)

- Resource: `aws_sns_topic`
- Name: `phi-audit-alerts`
- Resource: `aws_sns_topic_subscription`
- Protocol: `email`
- Endpoint: `var.alarm_email`

---

### 5. DynamoDB Table

- Resource: `aws_dynamodb_table`
- Name: `audit-incidents`
- Billing mode: `PAY_PER_REQUEST`
- Partition key: `incidentId` (String)
- No sort key

**Attributes to define:**
Only define the partition key attribute in Terraform. All other fields below are
written by Lambda at runtime — do not define them as DynamoDB attributes in Terraform.

**Full record schema (for Lambda reference):**
| Field | Type | Description |
|---|---|---|
| `incidentId` | String | UUID primary key |
| `actorId` | String | User or service that performed the access |
| `resourceAccessed` | String | FHIR-style resource path e.g. `Patient/12345/Observation` |
| `actionType` | String | `READ`, `WRITE`, `DELETE`, `BULK_EXPORT`, `AUTH_FAILURE` |
| `eventTime` | String | ISO 8601 UTC timestamp from the original log event |
| `ingestTime` | String | ISO 8601 UTC timestamp when Lambda processed the event |
| `severity` | String | `INFO`, `WARN`, `CRITICAL` |
| `logGroup` | String | Source CloudWatch Log Group name |
| `rawMessage` | String | Original log line, capped at 1 KB |

---

### 6. Lambda Function (module: lambda)

- Resource: `aws_lambda_function`
- Function name: `LogAlertProcessor`
- Runtime: `python3.12`
- Handler: `log_alert_processor.handler`
- Source: zip of `lambda/log_alert_processor.py`
- Timeout: `30`
- Environment variables:
  - `TABLE_NAME` = `audit-incidents`
  - `REGION` = `var.aws_region`

**Lambda function logic (`lambda/log_alert_processor.py`):**

The function receives a CloudWatch Logs event (base64-encoded, gzip-compressed).
For each log event in the batch:

1. Decode and decompress the payload
2. Parse the log message to extract:
   - `actorId` — match pattern `actor=(\S+)`
   - `resourceAccessed` — match pattern `resource=(\S+)`
   - `actionType` — infer from message keywords:
     - `UNAUTHORIZED` → `AUTH_FAILURE`
     - `bulk` or `BULK` → `BULK_EXPORT`
     - `DELETE` → `DELETE`
     - `WRITE` → `WRITE`
     - default → `READ`
   - `severity` — infer from log level or keywords:
     - `CRITICAL` if `AUTH_FAILURE` or `BULK_EXPORT` with records > 500
     - `WARN` if level is WARN
     - default → `INFO`
3. Write a record to DynamoDB with all fields from the schema above
4. On parse failure, write the record with `actionType=UNKNOWN` and `severity=WARN`
   rather than dropping it — audit completeness is required

**Dead-letter queue:** Attach an SQS DLQ to the Lambda function for failed invocations.
- Resource: `aws_sqs_queue`, name: `log-alert-processor-dlq`

---

### 7. IAM (module: lambda)

All policies must use specific resource ARNs — no `*` for actions or resources.

**Lambda execution role:**
- `dynamodb:PutItem` on the `audit-incidents` table ARN only
- `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents` on the Lambda
  log group ARN only
- `sqs:SendMessage` on the DLQ ARN only

**CloudWatch Logs invocation permission:**
- `aws_lambda_permission` allowing `logs.amazonaws.com` to invoke `LogAlertProcessor`
- Source ARN: the CloudWatch Log Group ARN

---

### 8. CloudWatch Logs Subscription Filter

- Resource: `aws_cloudwatch_log_subscription_filter`
- Name: `PHIAuditSubscriptionFilter`
- Log group: `var.log_group_name`
- Filter pattern: `"PHI"` (broad — Lambda handles fine-grained parsing)
- Destination ARN: `LogAlertProcessor` Lambda ARN

---

### 9. CloudWatch Dashboard (module: dashboard)

- Resource: `aws_cloudwatch_dashboard`
- Name: `PHI-Access-Audit-Dashboard`

Dashboard body JSON must include four widgets:

**Widget 1 — PHI Access Anomaly (line graph)**
- Type: `metric`
- Metrics: both `PHIAudit/PHIUnauthorizedAccess` and `PHIAudit/PHIBulkAccess`
- Period: `900`
- Title: `PHI Access Anomaly`

**Widget 2 — Alarm Status**
- Type: `alarm`
- Alarms: ARNs of both `PHIUnauthorizedAccess` and `PHIBulkAccess` alarms
- Title: `Alarm Status`

**Widget 3 — Recent Critical Incidents (Log Insights)**
- Type: `log`
- Query:
  ```
  fields @timestamp, @message
  | filter @message like /UNAUTHORIZED/ or @message like /BULK/
  | sort @timestamp desc
  | limit 20
  ```
- Log group: `var.log_group_name`
- Title: `Recent Critical Incidents`

**Widget 4 — Incident Volume by Action Type (bar graph)**
- Type: `metric`
- Use a metric math expression to show `PHIUnauthorizedAccess` and `PHIBulkAccess`
  side by side
- Title: `Incident Volume by Action Type`

---

## Outputs (outputs.tf)

| Output | Description |
|---|---|
| `log_group_name` | CloudWatch Log Group name |
| `sns_topic_arn` | SNS alert topic ARN |
| `lambda_function_arn` | LogAlertProcessor ARN |
| `dynamodb_table_name` | DynamoDB table name |
| `dashboard_url` | CloudWatch Dashboard URL |

---

## Tagging

Apply these tags to all supported resources:

```hcl
tags = {
  Project     = "hipaa-audit-logging"
  Environment = var.environment
  ManagedBy   = "terraform"
}
```

---

## Constraints & Notes

- **No `*` in IAM** — every policy must scope to a specific ARN
- **No plaintext ePHI** — Lambda must never log raw message content at INFO level;
  log only `incidentId` and `actionType` on success
- **Audit completeness over failure** — Lambda must write a degraded record on parse
  error rather than throwing and dropping the event
- **Email subscription** — SNS email subscriptions require manual confirmation after
  `terraform apply`; note this in the README
- **Dashboard JSON** — use `jsonencode()` in Terraform for the dashboard body rather
  than a raw heredoc string
