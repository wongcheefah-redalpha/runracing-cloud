output "players_table_name" {
  value       = aws_dynamodb_table.players.name
  description = "DynamoDB players table name."
}

output "players_table_arn" {
  value       = aws_dynamodb_table.players.arn
  description = "DynamoDB players table ARN."
}

output "leaderboards_table_name" {
  value       = aws_dynamodb_table.leaderboards.name
  description = "DynamoDB leaderboards table name."
}

output "leaderboards_table_arn" {
  value       = aws_dynamodb_table.leaderboards.arn
  description = "DynamoDB leaderboards table ARN."
}

output "replays_bucket" {
  value       = aws_s3_bucket.replays.id
  description = "S3 replays bucket name."
}

output "replays_bucket_arn" {
  value       = aws_s3_bucket.replays.arn
  description = "S3 replays bucket ARN."
}

output "assets_bucket" {
  value       = aws_s3_bucket.assets.id
  description = "S3 assets bucket name."
}

output "assets_bucket_arn" {
  value       = aws_s3_bucket.assets.arn
  description = "S3 assets bucket ARN."
}

output "assets_bucket_regional_domain" {
  value       = aws_s3_bucket.assets.bucket_regional_domain_name
  description = "Regional domain name of the assets bucket (CloudFront origin)."
}

output "data_lake_bucket" {
  value       = aws_s3_bucket.data_lake.id
  description = "S3 analytics data-lake bucket name."
}

output "data_lake_bucket_arn" {
  value       = aws_s3_bucket.data_lake.arn
  description = "S3 analytics data-lake bucket ARN."
}

output "redis_primary_endpoint" {
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
  description = "ElastiCache Redis primary endpoint."
}
