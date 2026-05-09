# =============================================================================
# environments/dev/main.tf
#
# Root configuration for the dev environment.
# Wires together all modules with dev-appropriate sizing and settings.
# =============================================================================

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "aws-observability-platform"
  }
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment

  vpc_cidr                  = "10.0.0.0/16"
  availability_zones        = ["eu-west-2a", "eu-west-2b"]
  public_subnet_cidrs       = ["10.0.1.0/24", "10.0.2.0/24"]
  private_app_subnet_cidrs  = ["10.0.10.0/24", "10.0.11.0/24"]
  private_data_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24"]
  flow_logs_retention_days  = 14
  tags                      = local.common_tags
}

# -----------------------------------------------------------------------------
# Security Groups
# -----------------------------------------------------------------------------
module "security_groups" {
  source = "../../modules/security-groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  tags         = local.common_tags
}

# -----------------------------------------------------------------------------
# IAM
# -----------------------------------------------------------------------------
module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

# -----------------------------------------------------------------------------
# ECR
# -----------------------------------------------------------------------------
module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

# -----------------------------------------------------------------------------
# RDS — Aurora PostgreSQL Serverless v2
# Dev uses minimal capacity to keep costs low.
# -----------------------------------------------------------------------------
module "rds" {
  source = "../../modules/rds"

  project_name            = var.project_name
  environment             = var.environment
  private_data_subnet_ids = module.vpc.private_data_subnet_ids
  rds_security_group_id   = module.security_groups.rds_security_group_id
  availability_zones      = ["eu-west-2a", "eu-west-2b"]
  db_name                 = "oteldb"
  db_master_username      = "oteladmin"
  serverless_min_capacity = 0.5
  serverless_max_capacity = 2
  tags                    = local.common_tags
}

# -----------------------------------------------------------------------------
# ElastiCache — Serverless Redis
# -----------------------------------------------------------------------------
module "elasticache" {
  source = "../../modules/elasticache"

  project_name                  = var.project_name
  environment                   = var.environment
  private_data_subnet_ids       = module.vpc.private_data_subnet_ids
  elasticache_security_group_id = module.security_groups.elasticache_security_group_id
  max_data_storage_gb           = 5
  max_ecpu_per_second           = 5000
  tags                          = local.common_tags
}

# -----------------------------------------------------------------------------
# ALB
# -----------------------------------------------------------------------------
module "alb" {
  source = "../../modules/alb"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_security_group_id
  certificate_arn       = var.certificate_arn
  alb_log_retention_days = 14
  tags                  = local.common_tags
}

# -----------------------------------------------------------------------------
# ECS
# -----------------------------------------------------------------------------
module "ecs" {
  source = "../../modules/ecs"

  project_name              = var.project_name
  environment               = var.environment
  aws_region                = var.aws_region
  vpc_id                    = module.vpc.vpc_id
  private_app_subnet_ids    = module.vpc.private_app_subnet_ids
  ecs_security_group_id     = module.security_groups.ecs_security_group_id
  task_execution_role_arn   = module.iam.ecs_task_execution_role_arn
  task_role_arns            = module.iam.ecs_task_role_arns
  ecr_repository_urls       = module.ecr.repository_urls
  frontend_target_group_arn = module.alb.frontend_target_group_arn
  desired_count             = 1
  min_count                 = 1
  max_count                 = 2
  log_retention_days        = 14
  tags                      = local.common_tags
}

# -----------------------------------------------------------------------------
# CloudWatch
# -----------------------------------------------------------------------------
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  project_name               = var.project_name
  environment                = var.environment
  ecs_cluster_name           = module.ecs.cluster_name
  alb_arn_suffix             = module.alb.alb_arn_suffix
  rds_cluster_id             = module.rds.cluster_id
  rds_max_connections        = 100
  elasticache_cluster_name   = module.elasticache.redis_cluster_name
  elasticache_max_storage_gb = 5
  alarm_email                = var.alarm_email
  tags                       = local.common_tags
}

# -----------------------------------------------------------------------------
# SSM Parameter Store
# -----------------------------------------------------------------------------
module "ssm" {
  source = "../../modules/ssm"

  project_name            = var.project_name
  environment             = var.environment
  aws_region              = var.aws_region
  otel_collector_endpoint = "http://otel-collector.${var.project_name}-${var.environment}.local:4317"
  frontend_port           = 8080
  log_level               = "INFO"
  alb_dns_name            = module.alb.alb_dns_name
  rds_endpoint            = module.rds.cluster_endpoint
  redis_endpoint          = module.elasticache.redis_endpoint
  tags                    = local.common_tags
}
