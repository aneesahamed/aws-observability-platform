# =============================================================================
# environments/dev/outputs.tf
# =============================================================================

output "vpc_id" {
  description = "ID of the dev VPC."
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "DNS name of the dev ALB — use this to access the OTel Demo frontend."
  value       = module.alb.alb_dns_name
}

output "ecs_cluster_name" {
  description = "Name of the dev ECS cluster."
  value       = module.ecs.cluster_name
}

output "ecr_repository_urls" {
  description = "Map of service name → ECR repository URL for dev."
  value       = module.ecr.repository_urls
}

output "rds_cluster_endpoint" {
  description = "Writer endpoint of the dev Aurora cluster."
  value       = module.rds.cluster_endpoint
  sensitive   = true
}

output "rds_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing dev RDS credentials."
  value       = module.rds.db_credentials_secret_arn
}

output "redis_endpoint" {
  description = "Endpoint of the dev ElastiCache Serverless Redis cluster."
  value       = module.elasticache.redis_endpoint
}

output "redis_auth_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the dev Redis auth token."
  value       = module.elasticache.redis_auth_token_secret_arn
}

output "cloudwatch_dashboard_name" {
  description = "Name of the dev CloudWatch dashboard."
  value       = module.cloudwatch.dashboard_name
}

output "alarm_sns_topic_arn" {
  description = "ARN of the SNS topic for dev CloudWatch alarms."
  value       = module.cloudwatch.alarm_sns_topic_arn
}
