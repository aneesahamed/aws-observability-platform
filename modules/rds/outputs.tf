# =============================================================================
# modules/rds/outputs.tf
# =============================================================================

output "cluster_id" {
  description = "The ID of the Aurora cluster."
  value       = aws_rds_cluster.main.id
}

output "cluster_endpoint" {
  description = "The writer endpoint of the Aurora cluster (for read/write connections)."
  value       = aws_rds_cluster.main.endpoint
}

output "cluster_reader_endpoint" {
  description = "The reader endpoint of the Aurora cluster (for read-only connections)."
  value       = aws_rds_cluster.main.reader_endpoint
}

output "cluster_port" {
  description = "The port on which the Aurora cluster accepts connections."
  value       = aws_rds_cluster.main.port
}

output "database_name" {
  description = "Name of the initial database created in the Aurora cluster."
  value       = aws_rds_cluster.main.database_name
}

output "db_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the DB credentials JSON."
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_credentials_secret_name" {
  description = "Name of the Secrets Manager secret containing the DB credentials JSON."
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group."
  value       = aws_db_subnet_group.main.name
}
