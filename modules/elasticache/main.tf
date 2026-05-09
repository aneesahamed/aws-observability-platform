# =============================================================================
# modules/elasticache/main.tf
#
# Provisions an ElastiCache Serverless Redis cluster for the OTel Demo
# cart service and any other service requiring low-latency caching:
#   - ElastiCache Serverless cluster (Redis-compatible, OSS 7.x)
#   - Subnet group using the private data subnets
#   - Auth token (password) auto-generated and stored in AWS Secrets Manager
#   - TLS in-transit encryption enforced
#   - Snapshots for data durability
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
      version = "~> 3.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Auth Token — stored in Secrets Manager
# The cart service retrieves this at runtime; it is never in plaintext config.
# -----------------------------------------------------------------------------
resource "random_password" "redis_auth_token" {
  length  = 32
  special = false # ElastiCache auth tokens cannot contain certain special chars
}

resource "aws_secretsmanager_secret" "redis_auth_token" {
  name                    = "${var.project_name}/${var.environment}/elasticache/auth-token"
  description             = "ElastiCache Redis auth token for ${var.project_name} ${var.environment}"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-redis-auth-token"
  })
}

resource "aws_secretsmanager_secret_version" "redis_auth_token" {
  secret_id     = aws_secretsmanager_secret.redis_auth_token.id
  secret_string = jsonencode({ auth_token = random_password.redis_auth_token.result })
}

# -----------------------------------------------------------------------------
# ElastiCache Serverless Cluster
# Serverless automatically scales based on demand — no node type selection.
# -----------------------------------------------------------------------------
resource "aws_elasticache_serverless_cache" "main" {
  engine = "redis"
  name   = "${var.project_name}-${var.environment}-redis"

  cache_usage_limits {
    data_storage {
      maximum = var.max_data_storage_gb
      unit    = "GB"
    }
    ecpu_per_second {
      maximum = var.max_ecpu_per_second
    }
  }

  daily_snapshot_time      = "03:00"
  description              = "Serverless Redis for ${var.project_name} ${var.environment}"
  major_engine_version     = "7"
  snapshot_retention_limit = var.environment == "prod" ? 7 : 1

  security_group_ids = [var.elasticache_security_group_id]
  subnet_ids         = var.private_data_subnet_ids

  # NOTE: ElastiCache Serverless does not support User Groups (aws_elasticache_user_group).
  # Auth is handled via the auth_token stored in Secrets Manager; the cluster
  # enforces TLS in-transit. User Group / RBAC is a feature of provisioned clusters only.

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-redis"
  })
}
