# =============================================================================
# modules/ecr/outputs.tf
# =============================================================================

output "repository_urls" {
  description = "Map of service name → ECR repository URL for every OTel Demo service."
  value       = { for svc, repo in aws_ecr_repository.service : svc => repo.repository_url }
}

output "repository_arns" {
  description = "Map of service name → ECR repository ARN for every OTel Demo service."
  value       = { for svc, repo in aws_ecr_repository.service : svc => repo.arn }
}

output "repository_names" {
  description = "Map of service name → ECR repository name for every OTel Demo service."
  value       = { for svc, repo in aws_ecr_repository.service : svc => repo.name }
}
