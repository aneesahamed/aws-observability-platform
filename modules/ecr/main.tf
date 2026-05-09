# =============================================================================
# modules/ecr/main.tf
#
# Provisions Amazon ECR repositories for every OTel Demo microservice:
#   frontend, cart, checkout, payment, shipping, email, recommendation,
#   ad, currency, quote, product-catalog, product-reviews, accounting,
#   fraud-detection, image-provider, load-generator, otel-collector
#
# Each repository has:
#   - Image scanning on push enabled (basic scan — upgrade to enhanced via
#     Inspector if needed)
#   - Lifecycle policy: retain the last 10 tagged images; expire untagged
#     images after 1 day
#   - Encryption at rest with AES-256 (default)
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

resource "aws_ecr_repository" "service" {
  for_each = toset(local.otel_services)

  name                 = "${var.project_name}-${var.environment}-${each.key}"
  # IMMUTABLE: once an image is pushed with a tag it cannot be
  # overwritten. Enforces traceability — you always know exactly
  # which image is running. To redeploy, push with a new tag.
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment}-${each.key}"
    Service = each.key
  })
}

# -----------------------------------------------------------------------------
# Lifecycle Policy
# Rule 1: Untagged images are expired after 1 day (avoids build garbage).
# Rule 2: Only the 10 most recent tagged images are retained.
# -----------------------------------------------------------------------------
resource "aws_ecr_lifecycle_policy" "service" {
  for_each   = toset(local.otel_services)
  repository = aws_ecr_repository.service[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "sha-", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# ECR Repository Policy — allow cross-account pull if needed (optional)
# Uncomment and configure if you need to pull from a separate CI/CD account.
# -----------------------------------------------------------------------------
# resource "aws_ecr_repository_policy" "service" {
#   for_each   = toset(local.otel_services)
#   repository = aws_ecr_repository.service[each.key].name
#   policy = jsonencode({...})
# }
