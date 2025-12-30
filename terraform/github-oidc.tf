# =============================================================================
# GitHub Actions OIDC Provider and IAM Role
# Creates an IAM role that GitHub Actions can assume without long-lived keys
# Run once, then remove or keep for reference
# =============================================================================

variable "github_repository" {
  description = "GitHub repository in format 'owner/repo'"
  type        = string
}

# GitHub OIDC Provider
# Note: If this already exists in your account, import it:
# terraform import aws_iam_openid_connect_provider.github arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  
  client_id_list = ["sts.amazonaws.com"]
  
  # GitHub's OIDC thumbprint
  thumbprint_list = ["1b511abead59c6ce207077c0bf0e0043b1382612"]
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name = "github-actions-ats-deploy"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:*"
          }
        }
      }
    ]
  })
  
  tags = {
    Name       = "GitHub Actions Deploy Role"
    Repository = var.github_repository
    ManagedBy  = "terraform"
  }
}

# Attach necessary policies
resource "aws_iam_role_policy_attachment" "github_lambda" {
  policy_arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
  role       = aws_iam_role.github_actions.name
}

resource "aws_iam_role_policy_attachment" "github_s3" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.github_actions.name
}

resource "aws_iam_role_policy_attachment" "github_apigateway" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonAPIGatewayAdministrator"
  role       = aws_iam_role.github_actions.name
}

resource "aws_iam_role_policy_attachment" "github_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
  role       = aws_iam_role.github_actions.name
}

resource "aws_iam_role_policy_attachment" "github_cloudwatch" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  role       = aws_iam_role.github_actions.name
}

resource "aws_iam_role_policy_attachment" "github_bedrock" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
  role       = aws_iam_role.github_actions.name
}

# Custom policy for additional permissions (IAM role management)
resource "aws_iam_role_policy" "github_additional" {
  name = "github-actions-additional"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:UpdateAssumeRolePolicy",
          "iam:PassRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:ListInstanceProfilesForRole",
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
  })
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}
