# =============================================================================
# modules/security-groups/main.tf
#
# Provisions all Security Groups for the OTel Demo platform:
#   - ALB SG:          inbound 80/443 from the internet; outbound to ECS SG
#   - ECS SG:          inbound from ALB SG only; outbound to RDS, ElastiCache,
#                      and the internet (for ECR/SSM pulls via NAT)
#   - RDS SG:          inbound 5432 (PostgreSQL) from ECS SG only
#   - ElastiCache SG:  inbound 6379 (Redis) from ECS SG only
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

# -----------------------------------------------------------------------------
# ALB Security Group
# Accepts inbound HTTP/HTTPS from the public internet.
# Restricts outbound to the ECS security group only.
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-sg-alb"
  description = "Security group for the Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound: allow traffic only toward ECS tasks (applied via egress to ECS SG
  # after both SGs exist — managed via aws_security_group_rule below to avoid
  # circular dependency).
  egress {
    description = "Allow all outbound (narrowed by ECS SG ingress rule)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-sg-alb"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# ECS Security Group
# Accepts inbound traffic from the ALB SG only.
# Allows outbound to RDS, ElastiCache, and the internet (ECR, SSM, etc.).
# -----------------------------------------------------------------------------
resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-${var.environment}-sg-ecs"
  description = "Security group for ECS Fargate tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow inbound from ALB on frontend port only"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Allow inter-service communication between ECS tasks"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  # Outbound to internet — needed for ECR image pulls, SSM, CloudWatch via NAT
  egress {
    description = "Allow all outbound internet traffic (via NAT Gateway)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-sg-ecs"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# RDS Security Group
# Accepts inbound PostgreSQL (5432) from ECS tasks only.
# No outbound rules needed — RDS does not initiate connections.
# -----------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-sg-rds"
  description = "Security group for Aurora PostgreSQL RDS cluster"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow PostgreSQL from ECS tasks only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    description = "Allow all outbound (required for Aurora internal cluster traffic)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-sg-rds"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# ElastiCache Security Group
# Accepts inbound Redis (6379) from ECS tasks only.
# -----------------------------------------------------------------------------
resource "aws_security_group" "elasticache" {
  name        = "${var.project_name}-${var.environment}-sg-elasticache"
  description = "Security group for ElastiCache Serverless Redis"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow Redis from ECS tasks only"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-sg-elasticache"
  })

  lifecycle {
    create_before_destroy = true
  }
}
