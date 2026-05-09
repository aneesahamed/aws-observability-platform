# =============================================================================
# modules/vpc/main.tf
#
# Provisions the core networking layer for the OTel Demo platform:
#   - 1 VPC with DNS hostnames and DNS resolution enabled
#   - 2 public subnets  (eu-west-2a, eu-west-2b) — ALB, NAT Gateway
#   - 2 private app subnets (eu-west-2a, eu-west-2b) — ECS Fargate tasks
#   - 2 private data subnets (eu-west-2a, eu-west-2b) — RDS, ElastiCache
#   - 1 Internet Gateway
#   - 1 NAT Gateway (in first public subnet) with an Elastic IP
#   - Route tables: public (→ IGW), private (→ NAT)
#   - Route table associations for all 6 subnets
#   - VPC Flow Logs → CloudWatch Logs
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
# VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-vpc"
  })
}

# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-igw"
  })
}

# -----------------------------------------------------------------------------
# Public Subnets (ALB + NAT Gateway tier)
# -----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-public-${var.availability_zones[count.index]}"
    Tier = "public"
  })
}

# -----------------------------------------------------------------------------
# Private App Subnets (ECS Fargate tier)
# -----------------------------------------------------------------------------
resource "aws_subnet" "private_app" {
  count = length(var.private_app_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-private-app-${var.availability_zones[count.index]}"
    Tier = "private-app"
  })
}

# -----------------------------------------------------------------------------
# Private Data Subnets (RDS + ElastiCache tier)
# -----------------------------------------------------------------------------
resource "aws_subnet" "private_data" {
  count = length(var.private_data_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_data_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-private-data-${var.availability_zones[count.index]}"
    Tier = "private-data"
  })
}

# -----------------------------------------------------------------------------
# Elastic IP for NAT Gateway
# -----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-nat-eip"
  })

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# NAT Gateway (single, in first public subnet)
# A single NAT Gateway is cost-effective for dev. For production HA, one per AZ
# can be introduced by converting this to a count-based resource.
# -----------------------------------------------------------------------------
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-nat-gw"
  })

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------------------------
# Route Table — Public (routes to Internet Gateway)
# -----------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-rt-public"
  })
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# Route Table — Private (routes to NAT Gateway)
# Shared by both app and data private subnets.
# -----------------------------------------------------------------------------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-rt-private"
  })
}

resource "aws_route_table_association" "private_app" {
  count = length(aws_subnet.private_app)

  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_data" {
  count = length(aws_subnet.private_data)

  subnet_id      = aws_subnet.private_data[count.index].id
  route_table_id = aws_route_table.private.id
}

# -----------------------------------------------------------------------------
# Architecture Decision Record: Shared Private Route Table
# Both private-app and private-data subnets currently share one route table.
# This is acceptable for dev. For production, consider separating data subnet
# routing to restrict outbound internet access from the data tier entirely
# (compliance requirement in regulated industries).
# Phase 2 improvement: create aws_route_table.private_data with no IGW/NAT
# route, forcing all data tier traffic to stay within the VPC.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# VPC Flow Logs → CloudWatch Logs
# Captures all accepted/rejected traffic for security auditing and debugging.
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs/${var.project_name}-${var.environment}"
  retention_in_days = var.flow_logs_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-vpc-flow-logs"
  })
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "${var.project_name}-${var.environment}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${var.project_name}-${var.environment}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
      }
    ]
  })
}

resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-vpc-flow-log"
  })
}

# -----------------------------------------------------------------------------
# Phase 2 — VPC Endpoints (not provisioned in dev to save cost)
# For production, add the following VPC Interface/Gateway Endpoints to keep
# traffic within the AWS network and reduce NAT Gateway data processing costs:
#   - aws_vpc_endpoint for S3 (Gateway type — free)
#   - aws_vpc_endpoint for DynamoDB (Gateway type — free)
#   - aws_vpc_endpoint for ECR API (Interface type)
#   - aws_vpc_endpoint for ECR DKR (Interface type)
#   - aws_vpc_endpoint for CloudWatch Logs (Interface type)
#   - aws_vpc_endpoint for Secrets Manager (Interface type)
# These prevent ECS tasks from routing traffic via NAT Gateway to reach
# AWS services, significantly reducing NAT costs at scale.
# -----------------------------------------------------------------------------
