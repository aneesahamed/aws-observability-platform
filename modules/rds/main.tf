# =============================================================================
# modules/rds/main.tf
#
# Provisions an Aurora PostgreSQL Serverless v2 cluster for the OTel Demo:
#   - Aurora PostgreSQL 16 Serverless v2 cluster
#   - 2 cluster instances spread across 2 AZs (Multi-AZ HA)
#   - DB subnet group using the private data subnets
#   - Custom parameter group (PostgreSQL 16 family)
#   - Credentials auto-generated and stored in AWS Secrets Manager
#   - Automated backups with 7-day retention
#   - Deletion protection enabled in prod, disabled in dev
#   - Storage encrypted with AWS-managed KMS key
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
# DB Subnet Group
# Uses the private data subnets so the cluster is never publicly reachable.
# -----------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-${var.environment}-db-subnet-group"
  description = "Subnet group for ${var.project_name} ${var.environment} Aurora cluster"
  subnet_ids  = var.private_data_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  })
}

# -----------------------------------------------------------------------------
# Parameter Group — Aurora PostgreSQL 16
# Baseline settings; extend as needed.
# -----------------------------------------------------------------------------
resource "aws_rds_cluster_parameter_group" "main" {
  name        = "${var.project_name}-${var.environment}-aurora-pg16"
  family      = "aurora-postgresql16"
  description = "Parameter group for ${var.project_name} ${var.environment} Aurora PostgreSQL 16"

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # Log queries slower than 1 s
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora-pg16"
  })
}

# -----------------------------------------------------------------------------
# Secrets Manager — DB credentials
# Terraform generates a random password; the secret ARN is output so ECS tasks
# can retrieve it at runtime without ever having it in plaintext config.
# -----------------------------------------------------------------------------
resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}/${var.environment}/rds/credentials"
  description             = "Aurora PostgreSQL credentials for ${var.project_name} ${var.environment}"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-rds-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_master_username
    password = random_password.db_password.result
    host     = aws_rds_cluster.main.endpoint
    port     = aws_rds_cluster.main.port
    dbname   = var.db_name
  })
}

# -----------------------------------------------------------------------------
# Aurora PostgreSQL Serverless v2 Cluster
# -----------------------------------------------------------------------------
resource "aws_rds_cluster" "main" {
  cluster_identifier = "${var.project_name}-${var.environment}-aurora-cluster"
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned" # Serverless v2 uses provisioned engine mode
  engine_version     = "16.6"

  database_name   = var.db_name
  master_username = var.db_master_username
  master_password = random_password.db_password.result

  db_subnet_group_name            = aws_db_subnet_group.main.name
  vpc_security_group_ids          = [var.rds_security_group_id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.main.name

  # Serverless v2 scaling configuration
  serverlessv2_scaling_configuration {
    min_capacity = var.serverless_min_capacity
    max_capacity = var.serverless_max_capacity
  }

  # Backup
  backup_retention_period   = 7
  preferred_backup_window   = "02:00-03:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  copy_tags_to_snapshot     = true
  skip_final_snapshot       = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${var.project_name}-${var.environment}-final-snapshot" : null

  # Security
  storage_encrypted   = true
  deletion_protection = var.environment == "prod" ? true : false

  # Enable enhanced monitoring data via CloudWatch
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora-cluster"
  })

  lifecycle {
    ignore_changes = [master_password]
  }
}

# -----------------------------------------------------------------------------
# Aurora Cluster Instances (2 for Multi-AZ)
# Using db.serverless instance class (required for Serverless v2).
# -----------------------------------------------------------------------------
resource "aws_rds_cluster_instance" "main" {
  count = 2

  identifier         = "${var.project_name}-${var.environment}-aurora-instance-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  availability_zone    = var.availability_zones[count.index]
  db_subnet_group_name = aws_db_subnet_group.main.name

  # Performance Insights — free tier available
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  auto_minor_version_upgrade = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora-instance-${count.index + 1}"
  })
}
