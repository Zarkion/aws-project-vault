output "lambda_function_arn" {
  description = "ARN of the LogAlertProcessor Lambda function"
  value       = aws_lambda_function.processor.arn
}
