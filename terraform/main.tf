# =============================================================================
# ATS Resume Analyzer - Terraform Infrastructure
# AWS Lambda + API Gateway + ECR (Cost-Optimized for Free Tier)
# =============================================================================

# Locals for naming conventions
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# Data Sources
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# ECR Repository
# =============================================================================

resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-${var.environment}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true  # Allow deletion even with images (dev-friendly)
  
  image_scanning_configuration {
    scan_on_push = false  # Disable for cost savings
  }
  
  # Lifecycle policy to keep only recent images (cost optimization)
  lifecycle {
    prevent_destroy = false
  }
}

# ECR Lifecycle Policy - Keep only last 3 images to save storage costs
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only last 3 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 3
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# =============================================================================
# IAM Role for Lambda
# =============================================================================

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role-${var.environment}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Basic Lambda execution policy (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Bedrock access policy
resource "aws_iam_role_policy" "bedrock_access" {
  name = "${var.project_name}-bedrock-access"
  role = aws_iam_role.lambda_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.nova-micro-v1:0",
          "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.nova-lite-v1:0"
        ]
      }
    ]
  })
}

# =============================================================================
# Lambda Function
# =============================================================================

resource "aws_lambda_function" "app" {
  function_name = "${var.project_name}-${var.environment}"
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.app.repository_url}:latest"
  
  # Memory and timeout optimized for free tier and cost
  memory_size = 512   # Minimum needed for PDF processing
  timeout     = 30    # 30 seconds should be enough
  
  environment {
    variables = {
      AWS_REGION_NAME = var.aws_region
      ENVIRONMENT     = var.environment
    }
  }
  
  # Depends on the ECR repository
  depends_on = [
    aws_ecr_repository.app,
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy.bedrock_access
  ]
  
  lifecycle {
    ignore_changes = [image_uri]  # Image updated via CI/CD
  }
}

# Lambda Function URL (Free alternative to API Gateway)
resource "aws_lambda_function_url" "app" {
  function_name      = aws_lambda_function.app.function_name
  authorization_type = "NONE"  # Public access
  
  cors {
    allow_origins     = ["*"]
    allow_methods     = ["GET", "POST", "OPTIONS"]
    allow_headers     = ["*"]
    allow_credentials = false
    max_age           = 3600
  }
}

# =============================================================================
# API Gateway (HTTP API - Cheaper than REST API)
# =============================================================================

resource "aws_apigatewayv2_api" "app" {
  name          = "${var.project_name}-api-${var.environment}"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["*"]
    max_age       = 3600
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.app.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.app.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.app.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.app.id
  name        = "$default"
  auto_deploy = true
  
  # Access logging (optional - costs money, disable for free tier)
  # access_log_settings {
  #   destination_arn = aws_cloudwatch_log_group.api_logs.arn
  # }
}

# Permission for API Gateway to invoke Lambda
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.app.execution_arn}/*/*"
}

# =============================================================================
# CloudWatch Log Group (with retention for cost optimization)
# =============================================================================

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.app.function_name}"
  retention_in_days = 7  # Short retention for cost savings
}
