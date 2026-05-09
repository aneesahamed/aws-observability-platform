# =============================================================================
# modules/security-groups/outputs.tf
# =============================================================================

output "alb_security_group_id" {
  description = "ID of the ALB security group."
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ID of the ECS Fargate tasks security group."
  value       = aws_security_group.ecs.id
}

output "rds_security_group_id" {
  description = "ID of the RDS Aurora security group."
  value       = aws_security_group.rds.id
}

output "elasticache_security_group_id" {
  description = "ID of the ElastiCache security group."
  value       = aws_security_group.elasticache.id
}
