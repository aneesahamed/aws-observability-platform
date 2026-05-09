# =============================================================================
# environments/prod/variables.tf
# =============================================================================

variable "project_name" {
  description = "Short name for the project, used as a prefix in all resource names."
  type        = string
  default     = "obs-platform"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "eu-west-2"
}

variable "alarm_email" {
  description = "Email address to subscribe to the CloudWatch alarm SNS topic."
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS on the ALB. Required in prod."
  type        = string
}
