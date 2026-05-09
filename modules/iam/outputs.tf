# =============================================================================
# modules/iam/outputs.tf
# =============================================================================

output "ecs_task_execution_role_arn" {
  description = "ARN of the shared ECS task execution role."
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_execution_role_name" {
  description = "Name of the shared ECS task execution role."
  value       = aws_iam_role.ecs_task_execution.name
}

output "ecs_task_role_arns" {
  description = "Map of service name → task role ARN for every OTel Demo service."
  value       = { for svc, role in aws_iam_role.ecs_task : svc => role.arn }
}

output "ecs_task_role_names" {
  description = "Map of service name → task role name for every OTel Demo service."
  value       = { for svc, role in aws_iam_role.ecs_task : svc => role.name }
}
