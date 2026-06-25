output "api_health_url" {
  description = "Full URL to the demo health endpoint."
  value       = "${module.compute.api_endpoint}/health"
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain (assets/replays CDN)."
  value       = module.edge.cloudfront_domain
}

output "players_table" {
  description = "DynamoDB players table name."
  value       = module.data.players_table_name
}

output "leaderboards_table" {
  description = "DynamoDB leaderboards table name."
  value       = module.data.leaderboards_table_name
}

output "replays_bucket" {
  description = "S3 replays bucket name."
  value       = module.data.replays_bucket
}

output "assets_bucket" {
  description = "S3 assets bucket name."
  value       = module.data.assets_bucket
}

output "data_lake_bucket" {
  description = "S3 analytics data-lake bucket name."
  value       = module.data.data_lake_bucket
}

output "redis_primary_endpoint" {
  description = "ElastiCache Redis primary endpoint."
  value       = module.data.redis_primary_endpoint
}

output "telemetry_stream" {
  description = "Kinesis telemetry stream name."
  value       = module.analytics.telemetry_stream_name
}

output "glue_database" {
  description = "Glue catalog database name."
  value       = module.analytics.glue_database
}

output "athena_workgroup" {
  description = "Athena workgroup name."
  value       = module.analytics.athena_workgroup
}

output "consumer_function" {
  description = "Real-time consumer Lambda name."
  value       = module.analytics.consumer_function_name
}
