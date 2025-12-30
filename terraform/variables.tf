# =============================================================================
# Variables
# =============================================================================

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "ap-south-2"  # Hyderabad, India
}

variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
  default     = "ats_test"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}
