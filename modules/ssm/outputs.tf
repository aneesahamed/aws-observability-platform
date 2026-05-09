# =============================================================================
# modules/ssm/outputs.tf
# =============================================================================

output "parameter_prefix" {
  description = "The SSM Parameter Store path prefix used by this module."
  value       = local.param_prefix
}

output "aws_region_param_arn" {
  description = "ARN of the aws_region SSM parameter."
  value       = aws_ssm_parameter.aws_region.arn
}

output "environment_param_arn" {
  description = "ARN of the environment SSM parameter."
  value       = aws_ssm_parameter.environment.arn
}

output "otel_collector_endpoint_param_arn" {
  description = "ARN of the otel_collector_endpoint SSM parameter."
  value       = aws_ssm_parameter.otel_collector_endpoint.arn
}

output "frontend_port_param_arn" {
  description = "ARN of the frontend_port SSM parameter."
  value       = aws_ssm_parameter.frontend_port.arn
}

output "log_level_param_arn" {
  description = "ARN of the log_level SSM parameter."
  value       = aws_ssm_parameter.log_level.arn
}

output "alb_dns_name_param_arn" {
  description = "ARN of the alb_dns_name SSM parameter."
  value       = aws_ssm_parameter.alb_dns_name.arn
}

output "rds_endpoint_param_arn" {
  description = "ARN of the rds_endpoint SSM parameter."
  value       = aws_ssm_parameter.rds_endpoint.arn
}

output "redis_endpoint_param_arn" {
  description = "ARN of the redis_endpoint SSM parameter."
  value       = aws_ssm_parameter.redis_endpoint.arn
}
