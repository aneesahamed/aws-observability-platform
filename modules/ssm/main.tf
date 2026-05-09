# =============================================================================
# modules/ssm/main.tf
#
# Provisions AWS Systems Manager Parameter Store parameters for the OTel Demo
# platform. These are non-sensitive configuration values that ECS tasks read
# at startup via the SSM Parameter Store integration.
#
# Sensitive values (passwords, tokens) are stored in Secrets Manager —
# see modules/rds and modules/elasticache.
#
# Parameters provisioned:
#   - /obs-platform/{env}/config/aws_region
#   - /obs-platform/{env}/config/environment
#   - /obs-platform/{env}/config/otel_collector_endpoint
#   - /obs-platform/{env}/config/frontend_port
#   - /obs-platform/{env}/config/log_level
# =============================================================================

terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  param_prefix = "/${var.project_name}/${var.environment}/config"
}

# -----------------------------------------------------------------------------
# Application configuration parameters
# These are String type — not SecureString — as they contain no secrets.
# -----------------------------------------------------------------------------
resource "aws_ssm_parameter" "aws_region" {
  name        = "${local.param_prefix}/aws_region"
  type        = "String"
  value       = var.aws_region
  description = "AWS region where the ${var.project_name} ${var.environment} stack is deployed"

  tags = merge(var.tags, {
    Name = "${local.param_prefix}/aws_region"
  })
}

resource "aws_ssm_parameter" "environment" {
  name        = "${local.param_prefix}/environment"
  type        = "String"
  value       = var.environment
  description = "Deployment environment name"

  tags = merge(var.tags, {
    Name = "${local.param_prefix}/environment"
  })
}

resource "aws_ssm_parameter" "otel_collector_endpoint" {
  name        = "${local.param_prefix}/otel_collector_endpoint"
  type        = "String"
  value       = var.otel_collector_endpoint
  description = "gRPC endpoint of the OTel Collector (used by all services)"

  tags = merge(var.tags, {
    Name = "${local.param_prefix}/otel_collector_endpoint"
  })
}

resource "aws_ssm_parameter" "frontend_port" {
  name        = "${local.param_prefix}/frontend_port"
  type        = "String"
  value       = tostring(var.frontend_port)
  description = "Port the OTel Demo frontend service listens on"

  tags = merge(var.tags, {
    Name = "${local.param_prefix}/frontend_port"
  })
}

resource "aws_ssm_parameter" "log_level" {
  name        = "${local.param_prefix}/log_level"
  type        = "String"
  value       = var.log_level
  description = "Log level for all OTel Demo services (e.g. INFO, DEBUG)"

  tags = merge(var.tags, {
    Name = "${local.param_prefix}/log_level"
  })
}

resource "aws_ssm_parameter" "alb_dns_name" {
  name        = "${local.param_prefix}/alb_dns_name"
  type        = "String"
  value       = var.alb_dns_name
  description = "DNS name of the Application Load Balancer"

  tags = merge(var.tags, {
    Name = "${local.param_prefix}/alb_dns_name"
  })
}

resource "aws_ssm_parameter" "rds_endpoint" {
  name        = "${local.param_prefix}/rds_endpoint"
  type        = "String"
  value       = var.rds_endpoint
  description = "Writer endpoint of the Aurora PostgreSQL cluster"

  tags = merge(var.tags, {
    Name = "${local.param_prefix}/rds_endpoint"
  })
}

resource "aws_ssm_parameter" "redis_endpoint" {
  name        = "${local.param_prefix}/redis_endpoint"
  type        = "String"
  value       = var.redis_endpoint
  description = "Endpoint of the ElastiCache Serverless Redis cluster"

  tags = merge(var.tags, {
    Name = "${local.param_prefix}/redis_endpoint"
  })
}
