# =============================================================================
# environments/dev/variables.tf
# =============================================================================

variable "project_name" {
  description = "Short name for the project, used as a prefix in all resource names."
  type        = string
  default     = "obs-platform"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "eu-west-2"
}

variable "alarm_email" {
  description = "Email address to subscribe to the CloudWatch alarm SNS topic."
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS on the ALB. Leave empty for HTTP-only in dev."
  type        = string
  default     = ""
}
