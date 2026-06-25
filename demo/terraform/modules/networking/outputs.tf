output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (for Lambda and ElastiCache)."
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = aws_subnet.public[*].id
}

output "lambda_sg_id" {
  description = "Security group ID for VPC-bound Lambdas."
  value       = aws_security_group.lambda.id
}

output "elasticache_sg_id" {
  description = "Security group ID for ElastiCache."
  value       = aws_security_group.elasticache.id
}
