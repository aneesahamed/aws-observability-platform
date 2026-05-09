# =============================================================================
# modules/rds/variables.tf
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
  description = "List of private data subnet IDs for the DB subnet group."
  type        = list(string)
}

variable "rds_security_group_id" {
  description = "ID of the security group to attach to the Aurora cluster."
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones to spread the 2 Aurora instances across."
  type        = list(string)
  default     = ["eu-west-2a", "eu-west-2b"]
}

variable "db_name" {
  description = "Name of the initial database to create in the Aurora cluster."
  type        = string
  default     = "oteldb"
}

variable "db_master_username" {
  description = "Master username for the Aurora cluster. Avoid 'admin' (reserved by AWS)."
  type        = string
  default     = "oteladmin"
}

variable "serverless_min_capacity" {
  description = "Minimum Aurora Serverless v2 capacity in ACUs (0.5 = minimum)."
  type        = number
  default     = 0.5
}

variable "serverless_max_capacity" {
  description = "Maximum Aurora Serverless v2 capacity in ACUs."
  type        = number
  default     = 4
}

variable "tags" {
  description = "Map of tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
