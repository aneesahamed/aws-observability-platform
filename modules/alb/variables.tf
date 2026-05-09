# =============================================================================
# modules/alb/variables.tf
# =============================================================================

variable "project_name" {
  description = "Short name for the project, used as a prefix in all resource names."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, prod)."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC in which to create the ALB and target group."
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs in which to place the ALB."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "ID of the security group to attach to the ALB."
  type        = string
}

variable "frontend_port" {
  description = "Container port that the OTel Demo frontend service listens on."
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "HTTP path used by the ALB target group health check."
  type        = string
  default     = "/"
}

variable "certificate_arn" {
  description = "ARN of an ACM certificate for HTTPS. Leave empty to use HTTP only."
  type        = string
  default     = ""
}

variable "alb_log_retention_days" {
  description = "Number of days to retain ALB access logs in S3."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Map of tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
