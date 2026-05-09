# =============================================================================
# modules/vpc/outputs.tf
# Values exported by the VPC module for consumption by other modules.
# =============================================================================

output "vpc_id" {
  description = "The ID of the VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "The primary CIDR block of the VPC."
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs of the public subnets (one per AZ)."
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "List of IDs of the private application subnets (ECS Fargate — one per AZ)."
  value       = aws_subnet.private_app[*].id
}

output "private_data_subnet_ids" {
  description = "List of IDs of the private data subnets (RDS, ElastiCache — one per AZ)."
  value       = aws_subnet.private_data[*].id
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway."
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "The ID of the NAT Gateway."
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_public_ip" {
  description = "The public Elastic IP address of the NAT Gateway."
  value       = aws_eip.nat.public_ip
}

output "public_route_table_id" {
  description = "The ID of the public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "The ID of the private route table (shared by app and data subnets)."
  value       = aws_route_table.private.id
}

output "vpc_flow_log_group_name" {
  description = "Name of the CloudWatch Log Group receiving VPC Flow Logs."
  value       = aws_cloudwatch_log_group.vpc_flow_logs.name
}
