# =============================================================================
# modules/ecs/main.tf
#
# Provisions the ECS Fargate cluster and all service/task definitions for the
# OTel Demo microservices application:
#   - 1 ECS Cluster with Container Insights enabled
#   - CloudWatch Log Groups for each service
#   - ECS Task Definitions (one per OTel Demo service)
#   - ECS Services with Fargate launch type, connected to the ALB
#     (frontend only) and the private app subnets
#   - Service auto-scaling based on CPU utilisation
#
# Services: frontend, cart, checkout, payment, shipping, email,
#           recommendation, ad, currency, quote, product-catalog,
#           product-reviews, accounting, fraud-detection, image-provider,
#           load-generator, otel-collector
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
  # Service definitions: name → { cpu, memory, port (0 = no port exposed) }
  services = {
    frontend = {
      cpu        = 256
      memory     = 512
      port       = 8080
      alb_target = true
    }
    cart = {
      cpu        = 256
      memory     = 512
      port       = 7070
      alb_target = false
    }
    checkout = {
      cpu        = 256
      memory     = 512
      port       = 5050
      alb_target = false
    }
    payment = {
      cpu        = 256
      memory     = 512
      port       = 50051
      alb_target = false
    }
    shipping = {
      cpu        = 256
      memory     = 512
      port       = 50051
      alb_target = false
    }
    email = {
      cpu        = 256
      memory     = 512
      port       = 5000
      alb_target = false
    }
    recommendation = {
      cpu        = 256
      memory     = 512
      port       = 9001
      alb_target = false
    }
    ad = {
      cpu        = 256
      memory     = 512
      port       = 9555
      alb_target = false
    }
    currency = {
      cpu        = 256
      memory     = 512
      port       = 7000
      alb_target = false
    }
    quote = {
      cpu        = 256
      memory     = 512
      port       = 8090
      alb_target = false
    }
    "product-catalog" = {
      cpu        = 256
      memory     = 512
      port       = 3550
      alb_target = false
    }
    "product-reviews" = {
      cpu        = 256
      memory     = 512
      port       = 9090
      alb_target = false
    }
    accounting = {
      cpu        = 256
      memory     = 512
      port       = 0
      alb_target = false
    }
    "fraud-detection" = {
      cpu        = 256
      memory     = 512
      port       = 0
      alb_target = false
    }
    "image-provider" = {
      cpu        = 256
      memory     = 512
      port       = 8081
      alb_target = false
    }
    "load-generator" = {
      cpu        = 256
      memory     = 512
      port       = 0
      alb_target = false
    }
    "otel-collector" = {
      cpu        = 512
      memory     = 1024
      port       = 4317
      alb_target = false
    }
  }
}

# -----------------------------------------------------------------------------
# ECS Cluster with Container Insights
# -----------------------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-cluster"
  })
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Log Groups — one per service
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "service" {
  for_each = local.services

  name              = "/ecs/${var.project_name}/${var.environment}/${each.key}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment}-logs-${each.key}"
    Service = each.key
  })
}

# -----------------------------------------------------------------------------
# ECS Task Definitions
# Each task definition references the ECR image and the per-service IAM role.
# The image URI is passed in as a variable map.
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "service" {
  for_each = local.services

  family                   = "${var.project_name}-${var.environment}-${each.key}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = lookup(var.task_role_arns, each.key, var.task_execution_role_arn)

  container_definitions = jsonencode([
    {
      name      = each.key
      image     = "${lookup(var.ecr_repository_urls, each.key, "")}"
      essential = true

      portMappings = each.value.port > 0 ? [
        {
          containerPort = each.value.port
          protocol      = "tcp"
        }
      ] : []

      environment = [
        {
          name  = "OTEL_SERVICE_NAME"
          value = each.key
        },
        {
          name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
          value = "http://otel-collector.${var.project_name}-${var.environment}.local:4317"
        },
        {
          name  = "ENV"
          value = var.environment
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.service[each.key].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = each.value.port > 0 ? {
        command     = ["CMD-SHELL", "echo healthy || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      } : null
    }
  ])

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment}-td-${each.key}"
    Service = each.key
  })
}

# -----------------------------------------------------------------------------
# ECS Services — all services run in private app subnets
# Frontend additionally registers with the ALB target group.
# -----------------------------------------------------------------------------
resource "aws_ecs_service" "service" {
  for_each = local.services

  name            = "${var.project_name}-${var.environment}-svc-${each.key}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.service[each.key].arn
  desired_count   = var.desired_count

  launch_type         = "FARGATE"
  scheduling_strategy = "REPLICA"

  network_configuration {
    subnets          = var.private_app_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = each.value.alb_target ? [1] : []
    content {
      target_group_arn = var.frontend_target_group_arn
      container_name   = each.key
      container_port   = each.value.port
    }
  }

  # Enable ECS Exec for debugging (useful in dev — can be disabled in prod)
  enable_execute_command = var.environment != "prod"

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  health_check_grace_period_seconds = each.value.alb_target ? 120 : null

  service_registries {
    registry_arn = aws_service_discovery_service.service[each.key].arn
  }

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment}-svc-${each.key}"
    Service = each.key
  })

  lifecycle {
    # desired_count is managed by auto-scaling; ignore drift.
    # task_definition is NOT ignored — Terraform should detect and deploy new image revisions.
    ignore_changes = [desired_count]
  }
}

# -----------------------------------------------------------------------------
# Service Discovery — private DNS namespace for inter-service communication
# Services call each other via <service>.{project}-{env}.local:<port> without
# going through the ALB, keeping east-west traffic off the public load balancer.
# -----------------------------------------------------------------------------
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.project_name}-${var.environment}.local"
  description = "Private DNS namespace for ${var.project_name} ${var.environment} service mesh"
  vpc         = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-dns-namespace"
  })
}

resource "aws_service_discovery_service" "service" {
  for_each = local.services

  name = each.key

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.main.id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {}

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${var.environment}-sd-${each.key}"
    Service = each.key
  })
}

# -----------------------------------------------------------------------------
# Auto-Scaling for ECS Services
# Scales on CPU utilisation. Memory scaling can be added similarly.
# -----------------------------------------------------------------------------
resource "aws_appautoscaling_target" "service" {
  for_each = local.services

  max_capacity       = var.max_count
  min_capacity       = var.min_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.service[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  for_each = local.services

  name               = "${var.project_name}-${var.environment}-${each.key}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.service[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.service[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
