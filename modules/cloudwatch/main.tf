# =============================================================================
# modules/cloudwatch/main.tf
#
# Provisions the CloudWatch observability stack for the OTel Demo platform:
#   - SNS topic for alarm notifications (subscribe an email via var.alarm_email)
#   - CloudWatch Dashboard with key metrics widgets
#   - ECS CPU utilisation alarm  (> 80%)
#   - ECS Memory utilisation alarm (> 80%)
#   - ALB 5xx error rate alarm  (> 1%)
#   - RDS DB connection count alarm (> 80% of max_connections)
#   - ElastiCache memory usage alarm (> 75%)
# All alarms are tagged with environment and project.
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
# SNS Topic for alarm notifications
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "alarms" {
  name = "${var.project_name}-${var.environment}-alarms"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-alarms"
  })
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# -----------------------------------------------------------------------------
# ECS CPU Utilisation Alarm
# Triggers if average CPU across any ECS service exceeds 80% for 5 minutes.
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS cluster average CPU utilisation exceeded 80% for 10 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-ecs-cpu-high"
  })
}

# -----------------------------------------------------------------------------
# ECS Memory Utilisation Alarm
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "ecs_memory" {
  alarm_name          = "${var.project_name}-${var.environment}-ecs-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS cluster average Memory utilisation exceeded 80% for 10 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-ecs-memory-high"
  })
}

# -----------------------------------------------------------------------------
# ALB 5xx Error Rate Alarm
# Uses a metric math expression: (5xx_count / request_count) * 100 > 1%
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 1
  alarm_description   = "ALB 5xx error rate exceeded 1% for 10 minutes"
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate"
    expression  = "errors / total * 100"
    label       = "5xx Error Rate (%)"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      metric_name = "HTTPCode_Target_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }
  }

  metric_query {
    id = "total"
    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions = {
        LoadBalancer = var.alb_arn_suffix
      }
    }
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-alb-5xx-high"
  })
}

# -----------------------------------------------------------------------------
# RDS Connection Count Alarm (> 80% of var.rds_max_connections)
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = floor(var.rds_max_connections * 0.8)
  alarm_description   = "RDS connection count exceeded 80% of max_connections for 10 minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = var.rds_cluster_id
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-rds-connections-high"
  })
}

# -----------------------------------------------------------------------------
# ElastiCache Memory Usage Alarm (> 75%)
# ElastiCache Serverless exposes BytesUsedForCache metric.
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "elasticache_memory" {
  alarm_name          = "${var.project_name}-${var.environment}-redis-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "BytesUsedForCache"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  # Threshold = 75% of max configured storage in bytes
  threshold          = floor(var.elasticache_max_storage_gb * 1073741824 * 0.75)
  alarm_description  = "ElastiCache Redis memory usage exceeded 75% of configured maximum for 10 minutes"
  treat_missing_data = "notBreaching"

  dimensions = {
    ServerlessCacheName = var.elasticache_cluster_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-redis-memory-high"
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Dashboard
# A single pane of glass showing the most important metrics.
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "## ${var.project_name} — ${var.environment} | OTel Demo Platform Dashboard"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "ECS CPU Utilisation (%)"
          view   = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, { stat = "Average", period = 300, color = "#2196F3" }]
          ]
          yAxis = { left = { min = 0, max = 100 } }
          annotations = { horizontal = [{ value = 80, color = "#FF5722", label = "Alarm threshold" }] }
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "ECS Memory Utilisation (%)"
          view   = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, { stat = "Average", period = 300, color = "#9C27B0" }]
          ]
          yAxis = { left = { min = 0, max = 100 } }
          annotations = { horizontal = [{ value = 80, color = "#FF5722", label = "Alarm threshold" }] }
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "ALB Request Count & 5xx Errors"
          view   = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", period = 300, color = "#4CAF50", label = "Requests" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum", period = 300, color = "#F44336", label = "5xx Errors" }]
          ]
          yAxis = { left = { min = 0 } }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 7
        width  = 8
        height = 6
        properties = {
          title  = "ALB Target Response Time (ms)"
          view   = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "p50", period = 60, color = "#00BCD4", label = "p50" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "p95", period = 60, color = "#FF9800", label = "p95" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "p99", period = 60, color = "#F44336", label = "p99" }]
          ]
          yAxis = { left = { min = 0 } }
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 7
        width  = 8
        height = 6
        properties = {
          title  = "RDS Database Connections"
          view   = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", var.rds_cluster_id, { stat = "Average", period = 300, color = "#FF9800" }]
          ]
          yAxis = { left = { min = 0 } }
          annotations = { horizontal = [{ value = floor(var.rds_max_connections * 0.8), color = "#FF5722", label = "80% of max" }] }
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 7
        width  = 8
        height = 6
        properties = {
          title  = "ElastiCache Memory (Bytes)"
          view   = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ElastiCache", "BytesUsedForCache", "ServerlessCacheName", var.elasticache_cluster_name, { stat = "Average", period = 300, color = "#E91E63" }]
          ]
          yAxis = { left = { min = 0 } }
        }
      },
      {
        type   = "alarm"
        x      = 0
        y      = 13
        width  = 24
        height = 4
        properties = {
          title = "Alarm Status"
          alarms = [
            aws_cloudwatch_metric_alarm.ecs_cpu.arn,
            aws_cloudwatch_metric_alarm.ecs_memory.arn,
            aws_cloudwatch_metric_alarm.alb_5xx.arn,
            aws_cloudwatch_metric_alarm.rds_connections.arn,
            aws_cloudwatch_metric_alarm.elasticache_memory.arn,
          ]
        }
      }
    ]
  })
}
