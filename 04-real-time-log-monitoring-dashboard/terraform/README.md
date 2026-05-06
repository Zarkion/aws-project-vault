# HIPAA PHI Access Audit Logging — Terraform

Deploys the full HIPAA PHI Access Audit pipeline: CloudWatch log group, metric filters,
alarms, SNS alerting, Lambda processor, DynamoDB audit table, and CloudWatch dashboard.

## Prerequisites

1. An S3 bucket and a DynamoDB table for Terraform remote state (create these manually).
2. Open `main.tf` and replace the backend placeholder values before running `terraform init`:

```hcl
backend "s3" {
  bucket         = "<your-state-bucket>"   # replace this
  key            = "hipaa-audit/terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "<your-lock-table>"     # replace this
  encrypt        = true
}
```

## Deploy

```bash
terraform init
terraform plan -var="alarm_email=you@example.com"
terraform apply -var="alarm_email=you@example.com"
```

## SNS Email Confirmation (required)

After `terraform apply`, AWS sends a subscription confirmation email to `alarm_email`.
**The SNS subscription is inactive until you click the confirmation link in that email.**
CloudWatch Alarms will not deliver notifications until the subscription is confirmed.

## Outputs

| Output | Description |
|---|---|
| `log_group_name` | CloudWatch Log Group name |
| `sns_topic_arn` | SNS alert topic ARN |
| `lambda_function_arn` | LogAlertProcessor Lambda ARN |
| `dynamodb_table_name` | DynamoDB audit incidents table name |
| `dashboard_url` | Direct link to the CloudWatch Dashboard |

## Destroy

```bash
terraform destroy -var="alarm_email=you@example.com"
```
