data "aws_caller_identity" "current" {}

resource "aws_sqs_queue" "dlq" {
  name = "log-alert-processor-dlq"
  tags = var.tags
}

resource "aws_iam_role" "lambda_exec" {
  name = "log-alert-processor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "lambda_exec" {
  name = "log-alert-processor-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = var.dynamodb_table_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/LogAlertProcessor:*"
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.dlq.arn
      }
    ]
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.root}/lambda/log_alert_processor.py"
  output_path = "${path.root}/lambda/log_alert_processor.zip"
}

resource "aws_lambda_function" "processor" {
  function_name = "LogAlertProcessor"
  runtime       = "python3.12"
  handler       = "log_alert_processor.handler"
  role          = aws_iam_role.lambda_exec.arn
  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout       = 30

  environment {
    variables = {
      TABLE_NAME = var.dynamodb_table_name
      REGION     = var.aws_region
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  tags = var.tags
}

resource "aws_lambda_permission" "allow_logs" {
  statement_id  = "AllowCloudWatchLogsInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "${var.log_group_arn}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "phi_filter" {
  name            = "PHIAuditSubscriptionFilter"
  log_group_name  = var.log_group_name
  filter_pattern  = "PHI"
  destination_arn = aws_lambda_function.processor.arn

  depends_on = [aws_lambda_permission.allow_logs]
}
