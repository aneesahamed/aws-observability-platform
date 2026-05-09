# =============================================================================
# modules/ssm/variables.tf
# =============================================================================

variable "project_name" {
  description = "Short name for the project, used as a prefix in all parameter paths."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, prod)."
  type        = string
}

variable "aws_region" {
  description = "AWS region where the stack is deployed."
  type        = string
}

variable "otel_collector_endpoint" {
  description = "gRPC endpoint of the OTel Collector (host:port)."
  type        = string
  default     = "http://otel-collector:4317"
}

variable "frontend_port" {
  description = "Port the OTel Demo frontend service listens on."
  type        = number
  default     = 8080
}

variable "log_level" {
  description = "Log level for all OTel Demo services."
  type        = string
  default     = "INFO"
}

variable "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  type        = string
}

variable "rds_endpoint" {
  description = "Writer endpoint of the Aurora PostgreSQL cluster."
  type        = string
}

variable "redis_endpoint" {
  description = "Endpoint address of the ElastiCache Serverless Redis cluster."
  type        = string
}

variable "tags" {
  description = "Map of tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
