# =============================================================================
# modules/elasticache/variables.tf
# =============================================================================

variable "project_name" {
  description = "Short name for the project, used as a prefix in all resource names."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, prod)."
  type        = string
}

variable "private_data_subnet_ids" {
  description = "List of private data subnet IDs for the ElastiCache subnet group."
  type        = list(string)
}

variable "elasticache_security_group_id" {
  description = "ID of the security group to attach to the ElastiCache cluster."
  type        = string
}

variable "max_data_storage_gb" {
  description = "Maximum data storage in GB for the Serverless Redis cluster."
  type        = number
  default     = 5
}

variable "max_ecpu_per_second" {
  description = "Maximum eCPU per second for the Serverless Redis cluster."
  type        = number
  default     = 5000
}

variable "tags" {
  description = "Map of tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
