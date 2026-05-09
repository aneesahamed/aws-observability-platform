# =============================================================================
# modules/alb/outputs.tf
# =============================================================================

output "alb_arn" {
  description = "Full ARN of the ALB"
  value       = aws_lb.main.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the ALB — used for CloudWatch metric dimensions"
  value       = aws_lb.main.arn_suffix
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (use as CNAME target)."
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID of the ALB (used for Route 53 alias records)."
  value       = aws_lb.main.zone_id
}

output "alb_name" {
  description = "Name of the Application Load Balancer."
  value       = aws_lb.main.name
}

output "frontend_target_group_arn" {
  description = "ARN of the frontend target group."
  value       = aws_lb_target_group.frontend.arn
}

output "frontend_target_group_name" {
  description = "Name of the frontend target group."
  value       = aws_lb_target_group.frontend.name
}

output "http_listener_arn" {
  description = "ARN of the HTTP (port 80) listener."
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS (port 443) listener, or null if no certificate was provided."
  value       = length(aws_lb_listener.https) > 0 ? aws_lb_listener.https[0].arn : null
}

output "alb_logs_bucket_name" {
  description = "Name of the S3 bucket storing ALB access logs."
  value       = aws_s3_bucket.alb_logs.id
}
