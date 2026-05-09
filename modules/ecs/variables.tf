# =============================================================================
# modules/ecs/variables.tf
# =============================================================================

variable "project_name" {
  description = "Short name for the project, used as a prefix in all resource names."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, prod)."
  type        = string
}

variable "aws_region" {
  description = "AWS region used in CloudWatch log configuration."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC."
  type        = string
}

variable "private_app_subnet_ids" {
  description = "List of private application subnet IDs in which ECS tasks run."
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "ID of the security group to attach to ECS Fargate tasks."
  type        = string
}

variable "task_execution_role_arn" {
  description = "ARN of the shared ECS task execution role."
  type        = string
}

variable "task_role_arns" {
  description = "Map of service name → task role ARN for each OTel Demo service."
  type        = map(string)
}

variable "ecr_repository_urls" {
  description = "Map of service name → ECR repository URL for each OTel Demo service."
  type        = map(string)
}

variable "frontend_target_group_arn" {
  description = "ARN of the ALB target group for the frontend service."
  type        = string
}

variable "desired_count" {
  description = "Desired number of running tasks per service."
  type        = number
  default     = 1
}

variable "min_count" {
  description = "Minimum number of tasks per service for auto-scaling."
  type        = number
  default     = 1
}

variable "max_count" {
  description = "Maximum number of tasks per service for auto-scaling."
  type        = number
  default     = 4
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch log streams for ECS services."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Map of tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
