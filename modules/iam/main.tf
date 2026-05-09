# =============================================================================
# modules/iam/main.tf
#
# Provisions all IAM roles and policies for the ECS workloads:
#   - ECS Task Execution Role (shared) — used by ECS to pull images and
#     write logs; attached to AmazonECSTaskExecutionRolePolicy + Secrets Manager
#     read for pulling secrets at container startup.
#   - Per-service ECS Task Roles — one per OTel Demo service, scoped to:
#       * Secrets Manager: read own service secrets
#       * CloudWatch Logs: write logs
#       * SSM Parameter Store: read parameters
#   Services: frontend, cart, checkout, payment, shipping, email,
#             recommendation, ad, currency, quote, product-catalog,
#             product-reviews, accounting, fraud-detection, image-provider,
#             load-generator, otel-collector
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

# Data sources to avoid hardcoding account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  otel_services = [
    "frontend",
    "cart",
    "checkout",
    "payment",
    "shipping",
    "email",
    "recommendation",
    "ad",
    "currency",
    "quote",
    "product-catalog",
    "product-reviews",
    "accounting",
    "fraud-detection",
    "image-provider",
    "load-generator",
    "otel-collector",
  ]
}

# -----------------------------------------------------------------------------
# ECS Task Execution Role (shared across all services)
# ECS itself assumes this role to:
#   - Pull container images from ECR
#   - Write container logs to CloudWatch
#   - Fetch secrets from Secrets Manager at container start
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-ecs-task-execution-role"
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Allow execution role to read any secret whose name starts with the project prefix.
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "${var.project_name}-${var.environment}-ecs-execution-secrets"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/*"
      },
      {
        Sid    = "SSMParameterRead"
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Per-service ECS Task Roles
# Application code inside each container assumes its own task role.
# Scoped tightly to the service's own secrets, logs, and parameters.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ecs_task" {
  for_each = toset(local.otel_services)

  name = "${var.project_name}-${var.environment}-task-role-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment}-task-role-${each.key}"
    Service = each.key
  })
}

resource "aws_iam_role_policy" "ecs_task_permissions" {
  for_each = toset(local.otel_services)

  name = "${var.project_name}-${var.environment}-task-policy-${each.key}"
  role = aws_iam_role.ecs_task[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/${each.key}/*"
      },
      {
        Sid    = "CloudWatchLogsWrite"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.project_name}/${var.environment}/${each.key}:*"
      },
      {
        Sid    = "SSMParameterRead"
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/${each.key}/*"
      },
      {
        Sid    = "XRayWrite"
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets"
        ]
        Resource = "*"
      }
    ]
  })
}
