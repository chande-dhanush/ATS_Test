# =============================================================================
# Outputs
# =============================================================================

output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.app.api_endpoint
}

output "lambda_function_url" {
  description = "Lambda Function URL (direct access)"
  value       = aws_lambda_function_url.app.function_url
}

output "ecr_repository_url" {
  description = "ECR repository URL for Docker images"
  value       = aws_ecr_repository.app.repository_url
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.app.function_name
}

output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}
