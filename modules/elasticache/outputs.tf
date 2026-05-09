# =============================================================================
# modules/elasticache/outputs.tf
# =============================================================================

output "redis_endpoint" {
  description = "The endpoint address of the Serverless Redis cluster."
  value       = aws_elasticache_serverless_cache.main.endpoint[0].address
}

output "redis_port" {
  description = "The port on which the Serverless Redis cluster accepts connections."
  value       = aws_elasticache_serverless_cache.main.endpoint[0].port
}

output "redis_auth_token_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the Redis auth token."
  value       = aws_secretsmanager_secret.redis_auth_token.arn
}

output "redis_auth_token_secret_name" {
  description = "Name of the Secrets Manager secret containing the Redis auth token."
  value       = aws_secretsmanager_secret.redis_auth_token.name
}

output "redis_cluster_name" {
  description = "Name of the ElastiCache Serverless Redis cluster."
  value       = aws_elasticache_serverless_cache.main.name
}
