# =============================================================================
# modules/cloudwatch/variables.tf
# =============================================================================

variable "project_name" {
  description = "Short name for the project, used as a prefix in all resource names."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, prod)."
  type        = string
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster to monitor."
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the ALB (the portion after 'app/') used in CloudWatch dimensions."
  type        = string
}

variable "rds_cluster_id" {
  description = "Identifier of the RDS Aurora cluster to monitor."
  type        = string
}

variable "rds_max_connections" {
  description = "Maximum allowed database connections for RDS alarm threshold calculation."
  type        = number
  default     = 100
}

variable "elasticache_cluster_name" {
  description = "Name of the ElastiCache Serverless cluster to monitor."
  type        = string
}

variable "elasticache_max_storage_gb" {
  description = "Maximum configured data storage (GB) for the ElastiCache cluster — used to calculate the memory alarm threshold."
  type        = number
  default     = 5
}

variable "alarm_email" {
  description = "Email address to subscribe to the SNS alarm topic. Leave empty to skip."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Map of tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
