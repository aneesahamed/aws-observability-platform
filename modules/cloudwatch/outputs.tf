# =============================================================================
# modules/cloudwatch/outputs.tf
# =============================================================================

output "alarm_sns_topic_arn" {
  description = "ARN of the SNS topic that receives CloudWatch alarm notifications."
  value       = aws_sns_topic.alarms.arn
}

output "alarm_sns_topic_name" {
  description = "Name of the SNS topic that receives CloudWatch alarm notifications."
  value       = aws_sns_topic.alarms.name
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard."
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "ecs_cpu_alarm_arn" {
  description = "ARN of the ECS CPU utilisation alarm."
  value       = aws_cloudwatch_metric_alarm.ecs_cpu.arn
}

output "ecs_memory_alarm_arn" {
  description = "ARN of the ECS Memory utilisation alarm."
  value       = aws_cloudwatch_metric_alarm.ecs_memory.arn
}

output "alb_5xx_alarm_arn" {
  description = "ARN of the ALB 5xx error rate alarm."
  value       = aws_cloudwatch_metric_alarm.alb_5xx.arn
}

output "rds_connections_alarm_arn" {
  description = "ARN of the RDS connection count alarm."
  value       = aws_cloudwatch_metric_alarm.rds_connections.arn
}

output "elasticache_memory_alarm_arn" {
  description = "ARN of the ElastiCache memory usage alarm."
  value       = aws_cloudwatch_metric_alarm.elasticache_memory.arn
}
