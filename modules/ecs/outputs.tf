# =============================================================================
# modules/ecs/outputs.tf
# =============================================================================

output "cluster_id" {
  description = "The ID of the ECS cluster."
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "The name of the ECS cluster."
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "The ARN of the ECS cluster."
  value       = aws_ecs_cluster.main.arn
}

output "service_names" {
  description = "Map of service key → ECS service name."
  value       = { for svc, s in aws_ecs_service.service : svc => s.name }
}

output "service_arns" {
  description = "Map of service key → ECS service ARN."
  value       = { for svc, s in aws_ecs_service.service : svc => s.id }
}

output "task_definition_arns" {
  description = "Map of service key → task definition ARN."
  value       = { for svc, td in aws_ecs_task_definition.service : svc => td.arn }
}

output "log_group_names" {
  description = "Map of service key → CloudWatch log group name."
  value       = { for svc, lg in aws_cloudwatch_log_group.service : svc => lg.name }
}
