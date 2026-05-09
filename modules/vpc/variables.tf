# =============================================================================
# modules/vpc/variables.tf
# Input variable definitions for the VPC module.
# =============================================================================

variable "project_name" {
  description = "Short name for the project, used as a prefix in all resource names."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, prod)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of Availability Zones to deploy subnets into. Must contain exactly 2 entries."
  type        = list(string)
  default     = ["eu-west-2a", "eu-west-2b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for the private application subnets (ECS Fargate — one per AZ)."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "private_data_subnet_cidrs" {
  description = "CIDR blocks for the private data subnets (RDS, ElastiCache — one per AZ)."
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "flow_logs_retention_days" {
  description = "Number of days to retain VPC Flow Log entries in CloudWatch Logs."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Map of tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
