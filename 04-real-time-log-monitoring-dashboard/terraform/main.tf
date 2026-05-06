terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "hipaa-audit-terraform-state-82lka"
    key            = "hipaa-audit/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  tags = {
    Project     = "hipaa-audit-logging"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_log_group" "app_logs" {
  name              = var.log_group_name
  retention_in_days = 90
  tags              = local.tags
}

resource "aws_dynamodb_table" "audit_incidents" {
  name         = "audit-incidents"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "incidentId"

  attribute {
    name = "incidentId"
    type = "S"
  }

  tags = local.tags
}

module "alerting" {
  source = "./modules/alerting"

  log_group_name = aws_cloudwatch_log_group.app_logs.name
  alarm_email    = var.alarm_email
  tags           = local.tags
}

module "lambda" {
  source = "./modules/lambda"

  dynamodb_table_arn  = aws_dynamodb_table.audit_incidents.arn
  dynamodb_table_name = aws_dynamodb_table.audit_incidents.name
  aws_region          = var.aws_region
  log_group_name      = aws_cloudwatch_log_group.app_logs.name
  log_group_arn       = aws_cloudwatch_log_group.app_logs.arn
  tags                = local.tags
}

module "dashboard" {
  source = "./modules/dashboard"

  alarm_unauthorized_arn = module.alerting.alarm_unauthorized_arn
  alarm_bulk_arn         = module.alerting.alarm_bulk_arn
  log_group_name         = aws_cloudwatch_log_group.app_logs.name
  aws_region             = var.aws_region
  tags                   = local.tags
}
