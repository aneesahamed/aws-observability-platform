# =============================================================================
# modules/alb/main.tf
#
# Provisions the Application Load Balancer and supporting resources:
#   - ALB (internet-facing) in the public subnets
#   - Target Group for ECS Fargate services (IP target type)
#   - HTTP listener (port 80) — can redirect to HTTPS once a certificate is added
#   - HTTPS listener (port 443) — conditional on var.certificate_arn being set
#   - Access logs stored in S3 (bucket created in this module)
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
# S3 Bucket for ALB Access Logs
# -----------------------------------------------------------------------------
data "aws_elb_service_account" "main" {}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${var.project_name}-${var.environment}-alb-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.environment != "prod"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-alb-logs"
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    expiration {
      days = var.alb_log_retention_days
    }
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket                  = aws_s3_bucket.alb_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowALBLogging"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      },
      {
        Sid    = "AllowSSLRequestsOnly"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.alb_logs.arn,
          "${aws_s3_bucket.alb_logs.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Application Load Balancer
# -----------------------------------------------------------------------------
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.environment == "prod" ? true : false
  enable_http2               = true
  idle_timeout               = 60

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb"
    enabled = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-alb"
  })

  depends_on = [aws_s3_bucket_policy.alb_logs]
}

# -----------------------------------------------------------------------------
# Target Group — ECS Fargate tasks (IP target type, health check on /)
# -----------------------------------------------------------------------------
resource "aws_lb_target_group" "frontend" {
  name        = "${var.project_name}-${var.environment}-tg-frontend"
  port        = var.frontend_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for Fargate

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  deregistration_delay = 30

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-tg-frontend"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# HTTP Listener — redirects to HTTPS when a certificate is provided,
# otherwise forwards directly to the target group.
# -----------------------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = var.certificate_arn != "" ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = var.certificate_arn == "" ? [1] : []
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.frontend.arn
    }
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# HTTPS Listener — only created when a certificate ARN is provided
# -----------------------------------------------------------------------------
resource "aws_lb_listener" "https" {
  count = var.certificate_arn != "" ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Phase 2 — WAF Web ACL Association
# Uncomment and configure when WAF is required:
#
# resource "aws_wafv2_web_acl_association" "alb" {
#   resource_arn = aws_lb.main.arn
#   web_acl_arn  = var.waf_web_acl_arn
# }
# -----------------------------------------------------------------------------
